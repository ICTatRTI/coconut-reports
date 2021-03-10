Tabulator = require 'tabulator-tables'

class NewLearnersView extends Backbone.View
  events:
    "click #region": "setRegion"
    "click #class": "setClass"

  setRegion: =>
    @region = @$("#region").val()
    @render()

  setClass: =>
    @className = @$("#class").val()
    @render()

  regionClassSelector: => 
    @className or= "Form 1"
  
    "
      Select the region: 
      <select id='region'>
        <option></option>
        #{
          (for region in ["Kakuma","Dadaab"]
            "<option #{if region is @region then "selected=true" else ""}>#{region}</option>"
          ).join("")
        }
      </select>

      Select the class: 
      <select id='class'>
        <option>All</option>
        #{
          classes = [
            "Standard 5"
            "Standard 6"
            "Standard 7"
            "Standard 8"
            "Form 1"
            "Form 2"
            "Form 3"
            "Form 4"
          ]
          (for className in classes
              "<option #{if className is @className then "selected=true" else ""}>#{className}</option>"
          ).join("")
        }
      </select>

    "

  render: =>
    unless @region
      @$el.html @regionClassSelector()
    else
      @$el.html "
        #{@regionClassSelector()}
        <h3 id='titleStatus'>
          Loading newly created learners from #{@region}.
        </h3>
        <div id='newLearners'/>
        <hr/>
        <div id='potentialMatches'/>
      "

      Coconut.peopleDB.query "newlyCreatedLearnersWithEnrollments",
        include_docs: false
        reduce:false
        startkey: [@region.toUpperCase()]
        endkey: [@region.toUpperCase(),{}]

      .then (result) =>
        @newlyCreatedLearnersWithEnrollments = []
        tableData = _(result.rows).chain().map (row) =>
          return unless row.id.match(/-.+-/) # only get unconfirmed people
          if @className isnt "All"
            return unless row.value["School Class"] is @className
          row.value.id = row.id
          @newlyCreatedLearnersWithEnrollments.push row.id
          row.value
        .compact().value()

        @renderTable(tableData)
        @findPotentialMatches()

  findPotentialMatches: =>
    @findPotentialMatchesCanceled = false
    return unless @table

    peopleAlreadyLinked = await Coconut.peopleDB.query "linksByPersonId",
      keys: @newlyCreatedLearnersWithEnrollments
    .then (result) =>
      peopleAlreadyLinked = {}

      for row in result.rows
        peopleAlreadyLinked[row.key] = true

      Promise.resolve _(peopleAlreadyLinked).keys()

    peopleById = {}
    counter = 0
    numberOfPersonsToFetch = 10
    console.log peopleAlreadyLinked
    peopleToFetch = _(@newlyCreatedLearnersWithEnrollments).difference peopleAlreadyLinked
    console.log peopleToFetch[0..10]
    new Promise (resolve, reject) =>
      while counter < peopleToFetch.length
        for person in await Person.get(peopleToFetch[counter..counter+numberOfPersonsToFetch])
          peopleById[person.longId()] = person
        counter+=numberOfPersonsToFetch

    percentWithLinks = Math.round(peopleAlreadyLinked.length / @newlyCreatedLearnersWithEnrollments.length * 100)
    @$("#learnersWithLinks").html "#{peopleAlreadyLinked.length} (#{percentWithLinks}%)"

    @$("#potentialMatches").html "<h3>Searching for potential matches for visible elements</h3>"
    Coconut.peopleDB.query "peopleByRegionAndGender",
      include_docs: false
      reduce:false
      startkey: [@region.toUpperCase()]
      endkey: [@region.toUpperCase(),{}]
    .then (result) =>
      #for rowComponent in @table.getRows(true)[0..numberToInvestigate]
      @$("#potentialMatches").html "
        <div style='font-size:large'>
        The above table lists all new learners that were created by Community Mobilizers when they couldn't find an existing learner already. The learners all have at least one enrollment. <br/>
        Ideally, each of these would either be:<br/>
          <br/>
          Linked to an existing learner<br/>
          Marked as a genuinely new learner<br/>
          <br/>
        Determining which of these to do for each learner will require additional investigation. The learners are being scored according to the likelihood of finding an easy and existing match (this is a slow process to try and do it for everyone). A bright <span style='background-color:yellow'>yellow color</span> suggests a likely match has been found. If the learner was confirmed or linked to an existing confirmed learner then the row is marked <span style='background-color:lightgreen'>green</span>.
        </div>
      "

      for rowComponent, count in @table.getRows(true)
        return if @findPotentialMatchesCanceled
        personId = rowComponent.getData().id

        if _(peopleAlreadyLinked).contains personId
          rowComponent.getElement().style["background-color"] = "lightgreen"

        else

          while not peopleById[personId]
            console.log "Waiting for #{personId}"
            await new Promise (resolve, reject) ->
              _.delay ->
                resolve()
              , 1000

          #await Person.get(personId).then (person) =>
          person = peopleById[personId]

          potentialDuplicates = await(person.findPotentialDuplicateFromArrayOfPeople(result.rows))
          if potentialDuplicates.length > 0
            if potentialDuplicates[0].score < 0.5
              @increment("#likelyMatch")
              rowComponent.getElement().style["background-color"] = "RGBA(240,255,0,#{1-(2*potentialDuplicates[0].score)}"

          delete peopleById[personId] # to keep memory from getting used up

        @updatePercentProcessed(count,@totalNewLearners)

  updatePercentProcessed: (done,target) =>
    @$("#processed").html "#{(done/target*100).toFixed(0)}%"

  increment: (target) =>
    value = parseInt(@$(target).html())
    @$(target).html(value+1)

  renderTable: (tableData) =>
    console.log tableData
    @totalNewLearners = tableData.length
    @$("#titleStatus").html "
    New learners from #{@region} (#{@totalNewLearners})
    Learners that have been linked: <span style='background-color:lightgreen' id='learnersWithLinks'>loading...</span>.<br/>
    Searching for matches <span id='processed'>0%</span> complete.
    Likely Matches: <span style='background-color:yellow' id='likelyMatch'>0</span>
    </div>
    "

    @table = new Tabulator "#newLearners",
      height:400
      data: tableData
      layout:"fitColumns"
      columns: [
        {title: "Name", field: "Name", headerFilter: true, formatter: "link", formatterParams: {url: (cellComponent) => "#admin/new_learner/#{cellComponent._cell.row.data.id}"}}
        {title: "ID", field: "id", headerFilter: true}
        #{title: "Region", field: "Region", headerFilter: true},
        {title: "School Name", field: "School Name", headerFilter: true}
        {title: "School Class", field: "School Class", headerFilter: true}
        #{title: "Sex", field: "Sex", headerFilter: "select", headerFilterParams:{"Male":"Male", "Female":"Female", "":""}, headerFilterFunc: "="},
      ]
      rowClick: (e, row) =>
        @findPotentialMatchesCanceled = true
        Coconut.router.navigate "admin/new_learner/#{row.getData().id}", trigger:true
      renderComplete: =>
        @findPotentialMatches()

module.exports = NewLearnersView