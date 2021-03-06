_ = require 'underscore'
$ = require 'jquery'
Backbone = require 'backbone'
Backbone.$  = $
moment = require 'moment'
DataTables = require( 'datatables.net' )()
Reports = require '../models/Reports'

class WeeklySummaryView extends Backbone.View
  el: "#content"

  render: =>
      HTMLHelpers.ChangeTitle("Reports: Weekly Summary")
      @reportOptions = $.extend({},Coconut.router.reportViewOptions)
      $('#analysis-spinner').show()
      @$el.html "
        <div id='dateSelector'></div>
        <div id='messages'></div>
      "
      $('#analysis-spinner').hide()

      #Last Monday (1) to Sunday (0 + 7)
      currentOptions = _.clone @reportOptions
      currentOptions.startDate = moment().day(1).format(Coconut.config.dateFormat)
      currentOptions.endDate = moment().day(0+7).format(Coconut.config.dateFormat)

      #previous Monday to Sunday
      previousOptions = _.clone @reportOptions
      previousOptions.startDate = moment().day(1-7).format(Coconut.config.dateFormat)
      previousOptions.endDate = moment().day(0+7-7).format(Coconut.config.dateFormat)

      previousPreviousOptions= _.clone @reportOptions
      previousPreviousOptions.startDate = moment().day(1-7-7).format(Coconut.config.dateFormat)
      previousPreviousOptions.endDate = moment().day(0+7-7-7).format(Coconut.config.dateFormat)

      previousPreviousPreviousOptions= _.clone @reportOptions
      previousPreviousPreviousOptions.startDate = moment().day(1-7-7-7).format(Coconut.config.dateFormat)
      previousPreviousPreviousOptions.endDate = moment().day(0+7-7-7-7).format(Coconut.config.dateFormat)

      @reportOptions.optionsArray = [previousPreviousPreviousOptions, previousPreviousOptions, previousOptions, currentOptions]
      $("#row-start").hide()
      $("#row-end").hide()
      @["Period Trends compared to previous 3 periods"](@reportOptions)


module.exports = WeeklySummaryView
