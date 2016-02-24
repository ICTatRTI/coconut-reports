_ = require 'underscore'
$ = require 'jquery'
Backbone = require 'backbone'
Backbone.$  = $

DataTables = require 'datatables'

class DashboardView extends Backbone.View
  el: "#content"

  events:
    "click button#dateFilter": "showForm"
  
  showForm: (e) =>
    e.preventDefault
    $("div#filters-section").slideToggle()

  render: =>

    @$el.html "
        <div id='dateSelector'></div>
    "
    Coconut.router.showDateFilter(@startDate,@endDate)

module.exports = DashboardView
