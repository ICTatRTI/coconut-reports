_ = require 'underscore'
moment = require 'moment'
$ = require 'jquery'

Chart = require 'chart.js'
ChartDataLabels = require 'chartjs-plugin-datalabels'
Chart.plugins.unregister(ChartDataLabels)

camelize = require "underscore.string/camelize"

class Graphs

  Graphs.render = (graphName, data, target) ->
    target or= camelize(graphName)
    console.log target
    Graphs.definitions[graphName].render(data, $("##{target}"))

  Graphs.getGraphName = (nameOrCamelizedName) ->
    return nameOrCamelizedName if Graphs.definitions[nameOrCamelizedName]

    camelizedNameToTile = {}
    for name of Graphs.definitions
      camelizedNameToTile[camelize(name)] = name
    if Graphs.definitions[camelizedNameToTile[nameOrCamelizedName]]
      camelizedNameToTile[nameOrCamelizedName]

  Graphs.weeklyDataCounter = (options) ->
    startDate = options.startDate
    endDate = options.endDate
    if _(startDate).isString()
      startDate = moment(startDate)
    if _(endDate).isString()
      endDate = moment(endDate)

    await Coconut.database.query "weeklyDataCounter",
      start_key: startDate.format("GGGG-WW").split(/-/)
      end_key: endDate.format("GGGG-WW").split(/-/)
      reduce: true
      include_docs: false
      group: true
    .then (result) =>
      Promise.resolve(result.rows)

  Graphs.caseCounter = (options) ->
    startDate = options.startDate
    endDate = options.endDate
    unless _(startDate).isString()
      startDate = startDate.format('YYYY-MM-DD')
    unless _(endDate).isString()
      endDate = endDate.format('YYYY-MM-DD')

    data = await Coconut.reportingDatabase.query "caseCounter",
      startkey: [startDate]
      endkey: [endDate,{}]
      reduce: true
      group_level: 2 # Group District and Shehia
      include_docs: false
    .then (result) =>
      Promise.resolve(result.rows)

  # This is a big data structure that is used to create the graphs on the dashboard as well as the individual graph pages as well as to create the menu options
  Graphs.definitions =
    "Positive Individuals by Year":
      description: "Positive Individuals by Year shows the 'classic' epidemiological curve comparing last year's total cases to this years. This is useful to see if general trends are higher or lower than the previous year."
      dataQuery: (options) ->

        # Only care about the endDate
        endDate = options.endDate
        if _(endDate).isString()
          endDate = moment(endDate)

        for label, data of {
          "#{lastYear = endDate.clone().subtract(1,'year').year()}":
            year: lastYear
            options:
              borderColor: "rgba(255, 64, 129,1)"
              backgroundColor: "rgba(255, 64, 129, 0.1)"
              pointRadius: 2
          "#{thisYear = endDate.year()}":
            year: thisYear
            options:
              borderColor: "rgba(25, 118, 210, 1)"
              backgroundColor: "rgba(25, 118, 210, 0.1)"
              pointRadius: 2
        }
          await Coconut.reportingDatabase.query "epiCurveByWeekAndDistrict",
            startkey: ["#{data.year}-01"]
            endkey: ["#{data.year}-52",{}]
            reduce: true
            group_level: 1
          .then (result) =>
            Promise.resolve _(data.options).extend {
              label: label
              data: for row in result.rows
                x: parseInt(row.key[0].replace(/.*-/,""))
                y: row.value
            }

      render: (dataForGraph, target) ->
        new Chart target,
          type: "line"
          data:
            labels: [1..52]
            datasets: dataForGraph
          options:
            scales:
              xAxes: [
                scaleLabel:
                  display: true
                  labelString: "Week"
              ]

    "Positive Individual Classifications":
      description: "Positive Individual Classifications shows classifications for all individuals that have been followed up. Note that the dates may differ slightly since this graph uses the date of testing for household members, which usually is different than the date that the index case was found positive, and which is used for other graphs on this page."
      dataQuery: Graphs.caseCounter
      render: (dataForGraph, target) ->
        dataAggregated = {}
        weeksIncluded = {}

        classifications = [
          "Indigenous"
          "Imported"
          "Introduced"
          "Induced"
          "Relapsing"
          "Unclassified"
        ]

        for data in dataForGraph
          if _(classifications).contains data.key[1]
            [date, classification] = data.key
            week = moment(date).isoWeek()
            dataAggregated[classification] or= {}
            dataAggregated[classification][week] or= 0
            dataAggregated[classification][week] += data.value
            weeksIncluded[week] = true

        chartOptions = for color in [
            [255,0, 0] # red
            [0, 0, 255] # blue
            [0, 100, 0] # darkgreen
            [128, 0, 128] # purple
            [255,128, 0] # orange
            [192,192, 0] # yellow
        ]
          {
            borderColor: "rgba(#{color.join(",")},1)"
            backgroundColor: "rgba(#{color.join(",")},0.1)"
            borderWidth: 2
          }

        index = -1
        dataSets = for classification in classifications
          index +=1
          _(chartOptions[index]).extend # Just use an index to get different colors
            label: classification
            data: for week, value of dataAggregated[classification]
              value

        xAxisLabels = []
        for week, index in _(weeksIncluded).keys()
          xAxisLabels.push week

        new Chart target,
          type: "bar"
          data:
            labels: xAxisLabels
            datasets: dataSets
          options:
            scales:
              xAxes: [
                stacked: true
                scaleLabel:
                  display: true
                  labelString: "Week"
              ]
              yAxes: [
                stacked: true
              ]
    "Positive Individuals by Age":
      description: "Positive Individuals by Age counts all malaria positive individuals and classifies them by age. Index case date of positive is used for all individuals."
      dataQuery: Graphs.caseCounter
      render: (dataForGraph, target) ->
        
        dataAggregated = {}
        weeksIncluded = {}

        for data in dataForGraph
          if data.key[1] is "Over 5" or data.key[1] is "Under 5"
            [date,age] = data.key
            week = moment(date).isoWeek()
            dataAggregated[age] or= {}
            dataAggregated[age][week] or= 0
            dataAggregated[age][week] += data.value
            weeksIncluded[week] = true

        chartOptions = [
          {
            borderColor: "rgba(25, 118, 210, 1)"
            backgroundColor: "rgba(25, 118, 210, 0.1)"
            pointRadius: 2
          }
          {
            borderColor: "rgba(255, 64, 129,1)"
            backgroundColor: "rgba(255, 64, 129, 0.1)"
            pointRadius: 2
          }
        ]

        index = -1
        dataSets = for age, weekValue of dataAggregated
          index +=1
          _(chartOptions[index]).extend # Just use an index to get different colors
            label: age
            data: for week, value of weekValue
              x: week
              y: value

        new Chart target,
          type: "line"
          data:
            labels: _(weeksIncluded).keys()
            datasets: dataSets
          options:
            scales:
              xAxes: [
                scaleLabel:
                  display: true
                  labelString: "Week"
              ]
    "OPD Visits By Age":
      description: "OPD Visits by Age shows data for all malaria and non-malaria visits to facilities."
      dataQuery: Graphs.weeklyDataCounter
      render: (dataForGraph, target) ->
        dataAggregated = {}
        weeksIncluded = {}

        mappings = 
          "All OPD >= 5" : "Over 5"
          "All OPD < 5"  : "Under 5"

        for data in dataForGraph
          if data.key[3] is "All OPD >= 5" or data.key[3] is "All OPD < 5"
            [year, week, location, dataType] = data.key
            dataType = mappings[dataType]
            week = parseInt(week)
            dataAggregated[dataType] or= {}
            dataAggregated[dataType][week] or= 0
            dataAggregated[dataType][week] += data.value
            weeksIncluded[week] = true

        chartOptions = [
          {
            borderColor: "rgba(25, 118, 210, 1)"
            backgroundColor: "rgba(25, 118, 210, 0.1)"
            pointRadius: 2
          }
          {
            borderColor: "rgba(255, 64, 129,1)"
            backgroundColor: "rgba(255, 64, 129, 0.1)"
            pointRadius: 2
          }
        ]

        index = -1
        dataSets = for age in _(mappings).values()
          index +=1
          _(chartOptions[index]).extend # Just use an index to get different colors
            label: age
            data: for week, value of dataAggregated[age]
              x: week
              y: value


        new Chart target,
          type: "line"
          data:
            labels: _(weeksIncluded).keys()
            datasets: dataSets
          options:
            scales:
              xAxes: [
                scaleLabel:
                  display: true
                  labelString: "Week"
              ]
    "Hours from Positive Test at Facility to Notification":
      description: "Shows how long it is taking facilities to send a notification once someone has tested positive. Target is less than 24 hours."
      dataQuery: Graphs.caseCounter
      render: (dataForGraph, target) ->
        dataAggregated = {}
        weeksIncluded = {}

        for data in dataForGraph
          if (data.value is 0 and data.key[1] is "Has Notification") or (data.value >= 1 and data.key[1].match( /Between Positive Result And Notification From Facility/))

            [datePositive, timeToNotify] = data.key
            week = moment(datePositive).isoWeek()

            mapping = 
              "Less Than One Day Between Positive Result And Notification From Facility": "< 24"
              "One To Two Days Between Positive Result And Notification From Facility": "24 - 48"
              "Two To Three Days Between Positive Result And Notification From Facility": "48 - 72"
              "More Than Three Days Between Positive Result And Notification From Facility": "> 72"
              "Has Notification": "No notification" # This Has Notification = 0

            timeToNotify = mapping[timeToNotify]

            weeksIncluded[week] = true
            dataAggregated[timeToNotify] or= {}
            dataAggregated[timeToNotify][week] or= 0
            if timeToNotify is "No notification"
              dataAggregated[timeToNotify][week] += 1
            else
              dataAggregated[timeToNotify][week] += data.value
          
        chartOptions = for color in [
            [0, 128, 0] # green
            [192,192, 0] # yellow
            [255,128, 0] # orange
            [255,0, 0] # red
        ]
          {
            borderColor: "rgba(#{color.join(",")},1)"
            backgroundColor: "rgba(#{color.join(",")},0.1)"
            borderWidth: 2
          }

        index = -1
        dataSets = for type in _(mapping).values() # Do this to get the right order
          continue unless dataAggregated[type]
          index +=1
          _(chartOptions[index]).extend # Just use an index to get different colors
            label: type
            data: for week, value of dataAggregated[type]
              value

        xAxisLabels = []
        onTarget = []
        for week, index in _(weeksIncluded).keys()
          xAxisLabels.push week
          total = 0
          for dataSet in dataSets
            total += dataSet.data[index] or 0

          onTarget.push Math.round(dataSets[0].data[index] / total * 100)

        new Chart target,
          type: "bar"
          data:
            labels: xAxisLabels
            datasets: dataSets
          plugins: [ChartDataLabels] # Lets us put the percent over the bar
          options:
            scales:
              xAxes: [
                stacked: true
                scaleLabel:
                  display: true
                  labelString: "Week"
              ]
              yAxes: [
                stacked: true
              ]
            plugins:
              datalabels:
                align: 'top'
                anchor: 'start'
                borderRadius: 4
                color: 'green'
                formatter: (value, context) ->
                  return null if context.datasetIndex > 0 # Only need one percent per dataset since the calculation uses both parts of the bar
                  "#{onTarget[context.dataIndex]}%"

    "Hours From Positive Test To Complete Follow-up":
      description: "Shows how long it is taking the entire followup process to take including both the time for the facility to followup as well as time for the surveillance officer to go to the facility and then go to the household. Target is less than 48 hours."
      dataQuery: Graphs.caseCounter
      render: (dataForGraph, target) ->
        dataAggregated = {}
        weeksIncluded = {}

        for data in dataForGraph
          if (data.value is 0 and data.key[1] is "Followed Up") or (data.value >= 1 and data.key[1].match( /Between Positive Result And Complete Household/))

            [datePositive, timeToComplete] = data.key

            week = moment(datePositive).isoWeek()

            mapping = 
              "Less Than One Day Between Positive Result And Complete Household": "< 48"
              "One To Two Days Between Positive Result And Complete Household": "< 48"
              "Two To Three Days Between Positive Result And Complete Household": "48 -  72"
              "More Than Three Days Between Positive Result And Complete Household": "> 72"
              "Followed Up": "Not followed up" #Confusing but when followed up is 0 then it is not followed up

            timeToComplete = mapping[timeToComplete]

            weeksIncluded[week] = true
            dataAggregated[timeToComplete] or= {}
            dataAggregated[timeToComplete][week] or= 0
            if timeToComplete is "Not followed up"
              dataAggregated[timeToComplete][week] += 1
            else
              dataAggregated[timeToComplete][week] += data.value
              
        chartOptions = for color in [
            [0, 128, 0] # green
            [192,192, 0] # yellow
            [255,128, 0] # orange
            [255,0, 0] # red
        ]
          {
            borderColor: "rgba(#{color.join(",")},1)"
            backgroundColor: "rgba(#{color.join(",")},0.1)"
            borderWidth: 2
          }

        index = -1
        dataSets = for type in _(mapping).chain().values().uniq().value()
          continue unless dataAggregated[type]
          index +=1
          _(chartOptions[index]).extend # Just use an index to get different colors
            label: type
            data: for week, value of dataAggregated[type]
              value

        xAxisLabels = []
        onTarget = []
        for week, index in _(weeksIncluded).keys()
          xAxisLabels.push week
          total = 0
          for dataSet in dataSets
            total += dataSet.data[index] or 0

          onTarget.push Math.round(dataSets[0].data[index] / total * 100)

        new Chart target,
          type: "bar"
          data:
            labels: xAxisLabels
            datasets: dataSets
          plugins: [ChartDataLabels] # Lets us put the percent over the bar
          options:
            scales:
              xAxes: [
                stacked: true
                scaleLabel:
                  display: true
                  labelString: "Week"
              ]
              yAxes: [
                stacked: true
              ]
            plugins:
              datalabels:
                align: 'top'
                anchor: 'start'
                borderRadius: 4
                color: 'green'
                formatter: (value, context) ->
                  return null if context.datasetIndex > 0 # Only need one percent per dataset since the calculation uses both parts of the bar
                  "#{onTarget[context.dataIndex]}%"

    "Household Testing and Positivity Rate":
      description: "How many tests are being given at households, and how many of those end up being positive."
      dataQuery: Graphs.caseCounter
      render: (dataForGraph, target) ->

        dataAggregated = {}
        weeksIncluded = {}

        for data in dataForGraph

          [date, indicator] = data.key

          if indicator is "Number Household Members Tested"
            week = moment(date).isoWeek()
            weeksIncluded[week] = true
            dataAggregated["Negative"] or= {}
            dataAggregated["Negative"][week] or= -1 # Includes the index case so remove that for this graph
            dataAggregated["Negative"][week] += data.value
          else if indicator is "Number Positive Individuals At Household Excluding Index"
            week = moment(date).isoWeek()
            weeksIncluded[week] = true
            dataAggregated["Positive"] or= {}
            dataAggregated["Positive"][week] or= 0
            dataAggregated["Positive"][week] += data.value
            # Subtract these from negative count
            dataAggregated["Negative"] or= {}
            dataAggregated["Negative"][week] or= 0
            dataAggregated["Negative"][week] -= data.value

        chartOptions = [
          {
            borderColor: "rgba(25, 118, 210, 1)"
            backgroundColor: "rgba(25, 118, 210, 0.1)"
            borderWidth: 2
          }
          {
            borderColor: "rgba(255, 64, 129, 1)"
            backgroundColor: "rgba(255, 64, 129, 0.5)"
            borderWidth: 2
          }
        ]

        index = -1
        dataSets = for type, weekValue of dataAggregated
          index +=1
          _(chartOptions[index]).extend # Just use an index to get different colors
            label: type
            data: for week, value of weekValue
              value

        xAxisLabels = []
        positivityRate = []
        for week, index in _(weeksIncluded).keys()
          xAxisLabels.push week
          positivityRate.push Math.round((dataSets[1].data[index]/dataSets[0].data[index])*100)

        new Chart target,
          type: "bar"
          data:
            labels: xAxisLabels
            datasets: dataSets
          plugins: [ChartDataLabels] # Lets us put the percent over the bar
          options:
            scales:
              xAxes: [
                stacked: true
                scaleLabel:
                  display: true
                  labelString: "Week"
              ]
              yAxes: [
                stacked: true
              ]
            plugins:
              datalabels:
                align: 'top',
                anchor: 'end',
                borderRadius: 4,
                color: 'black',
                formatter: (value, context) ->
                  return null if context.datasetIndex > 0 # Only need one percent per dataset since the calculation uses both parts of the bar
                  "#{positivityRate[context.dataIndex]}%"

    "OPD Testing and Positivity Rate":
      description: "How many tests are being given at facilities, and how many of those end up positive."
      dataQuery: Graphs.weeklyDataCounter
      render: (dataForGraph, target) ->
        dataAggregated = {}
        weeksIncluded = {}

        for data in dataForGraph
          [year, week, location, dataType] = data.key
          week = parseInt(week)
          weeksIncluded[week] = true

          if dataType.match /POS/
            dataAggregated["Positive"] or= {}
            dataAggregated["Positive"][week] or= 0
            dataAggregated["Positive"][week] += data.value

          if dataType.match /NEG/
            dataAggregated["Negative"] or= {}
            dataAggregated["Negative"][week] or= 0
            dataAggregated["Negative"][week] += data.value

        chartOptions = [
          {
            borderColor: "rgba(25, 118, 210, 1)"
            backgroundColor: "rgba(25, 118, 210, 0.1)"
            borderWidth: 2
          }
          {
            borderColor: "rgba(255, 64, 129, 1)"
            backgroundColor: "rgba(255, 64, 129, 0.5)"
            borderWidth: 2
          }
        ]

        index = -1
        dataSets = for type, weekValue of dataAggregated
          index +=1
          _(chartOptions[index]).extend # Just use an index to get different colors
            label: type
            data: for week, value of weekValue
              value

        xAxisLabels = []
        positivityRate = []
        for week, index in _(weeksIncluded).keys()
          xAxisLabels.push week
          positivityRate.push Math.round((dataSets[1].data[index]/dataSets[0].data[index])*100)

        new Chart target,
          type: "bar"
          data:
            labels: xAxisLabels
            datasets: dataSets
          plugins: [ChartDataLabels] # Lets us put the percent over the bar
          options:
            scales:
              xAxes: [
                stacked: true
                scaleLabel:
                  display: true
                  labelString: "Week"
              ]
              yAxes: [
                stacked: true
              ]
            plugins:
              datalabels:
                align: 'top',
                anchor: 'end',
                borderRadius: 4,
                color: 'black',
                formatter: (value, context) ->
                  return null if context.datasetIndex > 0 # Only need one percent per dataset since the calculation uses both parts of the bar
                  "#{positivityRate[context.dataIndex]}%"

module.exports = Graphs
