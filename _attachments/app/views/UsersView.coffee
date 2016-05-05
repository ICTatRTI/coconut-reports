_ = require 'underscore'
$ = require 'jquery'
Backbone = require 'backbone'
Backbone.$  = $

global.jQuery = require 'jquery'
require 'tablesorter'
Common = require './Common'
humanize = require 'underscore.string/humanize'
Form2js = require 'form2js'
js2form = require 'form2js'

moment = require 'moment'

DataTables = require 'datatables'
User = require '../models/User'
UserCollection = require '../models/UserCollection'

class UsersView extends Backbone.View
    el:'#content'
    events:
      "click #new-user-btn": "createUser"
      "click a.user-edit": "editUser"
      "click a.user-delete": "deleteDialog"
      "click #formSave": "formSave"
      "click #formCancel": "formCancel"
      "click button#buttonYes": "deleteUser"

    createUser: (e) =>
      e.preventDefault
      dialogTitle = "Add New User"
      Common.createDialog(@dialogEdit, dialogTitle)
      $('form#user input').val('')
      return false

    editUser: (e) =>
      e.preventDefault
      dialogTitle = "Edit User"
      Common.createDialog(@dialogEdit, dialogTitle)
      id = $(e.target).closest("a").attr "data-user-id"
      
      Coconut.database.get id,
         include_docs: true
      .catch (error) -> console.error error
      .then (user) =>
         @user = _.clone(user)
         user._id = user._id.substring(5)
         Form2js.js2form($('form#user').get(0), user)
         if (user.roles)
           for role in user.roles
             $("[name=role][value=#{role}]").prop("checked", true)
         Common.markTextfieldDirty()
       return false
	   
    formSave: =>
      if not @user
        @user = {
          _id: "user." + $("#_id").val()
        }
      
      @user.inactive = $("#inactive").is(":checked")
      @user.isApplicationDoc = true
      @user.district = $("#district").val().toUpperCase()
      @user.password = $('#password').val()
      @user.name = $('#name').val()
      @user.roles = $('#roles').val()
      @user.comments = $('#comments').val()

      console.log @user
      dialog.close()
      Coconut.database.put @user
      .catch (error) -> console.error error
      .then =>
        @render()

    deleteDialog: (e) =>
      e.preventDefault
      dialogTitle = "Are you sure?"
      Common.createDialog(@dialogConfirm, dialogTitle) 
      console.log("Delete initiated")
      return false

    deleteUser: (e) =>
      e.preventDefault
      console.log("User Deleted")
      dialog.close()
      return false
	
    formCancel: (e) =>
      e.preventDefault
      console.log("Cancel pressed")

    # On saving 
    # Coconut.database.get "user.id"
    # (result) ->       
    # result._rev # what you ned
    # 
    # Create a user from the input fields: createdUser
    # Then add a _rev field from the above get: createdUser._rev = result.document._rev
    # Then you can save the document by doing
    # Coconut.database.put createdUser

    render: =>
      Coconut.database.query "zanzibar-server/users",
        include_docs: true
      .catch (error) -> console.error error
      .then (result) =>
        users = _(result.rows).pluck("doc")

        @fields =  "_id,password,district,name,roles,comments".split(",")
        @dialogEdit = "
          <form id='user' method='dialog'>
             <div id='dialog-title'> </div>
             <div>
                <ul>
                  <li>DMSO's must have a username that corresponds to their phone number.</li>
                  <li>If a DMSO is no longer working, mark their account as inactive to stop notification messages from being sent.</li>
                </ul>
             </div>
             #{
              _.map( @fields, (field) =>
                "
                   <div class='mdl-textfield mdl-js-textfield mdl-textfield--floating-label'>
                     <input class='mdl-textfield__input' type='text' id='#{if field is 'password' then 'passwd' else field }' name='#{field}' #{if field is "_id" and not @user then "readonly='true'" else ""}></input>
                     <label class='mdl-textfield__label' for='#{field}'>#{if field is '_id' then 'Username' else humanize(field)}</label>
                   </div>
                "
                ).join("")
              }
              <label class='mdl-switch mdl-js-switch mdl-js-ripple-effect' for='inactive'>
                   <input type='checkbox' id='inactive' class='mdl-switch__input'>
                   <span class='mdl-switch__label'>Inactive</span>
              </label>
              <div id='dialogActions'>
               <button class='mdl-button mdl-js-button mdl-button--primary' id='formSave' type='submit' value='save'><i class='material-icons'>save</i> Save</button> &nbsp;
               <button class='mdl-button mdl-js-button mdl-button--primary' id='formCancel' type='submit' value='cancel'><i class='material-icons'>cancel</i> Cancel</button>
              </div> 
          </form>
        "

        @dialogConfirm = "
          <form method='dialog'>
            <div id='dialog-title'> </div>
            <div>This will permanently remove the record.</div>
            <div id='dialogActions'>
              <button type='submit' id='buttonYes' class='mdl-button mdl-js-button mdl-button--primary' value='yes'>Yes</button>
              <button type='submit' id='buttonNo' class='mdl-button mdl-js-button mdl-button--primary' value='no' autofocus>No</button>
            </div>
          </form>
        "
        @$el.html "
            <h4>Users <button class='mdl-button mdl-js-button mdl-button--fab mdl-button--mini-fab mdl-button--colored' id='new-user-btn'>
              <i class='material-icons'>add</i>
            </button></h4>
            <dialog id='dialog'>
              <div id='dialogContent'> </div>
            </dialog>

            <div id='results' class='result'>
              <table class='summary tablesorter mdl-data-table mdl-js-data-table mdl-shadow--2dp'>
                <thead>
                  <tr> 
                  <th class='header headerSortUp mdl-data-table__cell--non-numeric'>Username</th>
                  <th class='mdl-data-table__cell--non-numeric'>Password</th>
                  <th class='header mdl-data-table__cell--non-numeric'>District</th>
                  <th class='header mdl-data-table__cell--non-numeric'>Name</th>
                  <th class='header mdl-data-table__cell--non-numeric'>Roles</th>
                  <th class='mdl-data-table__cell--non-numeric'>Comments</th>
                  <th class='header mdl-data-table__cell--non-numeric'>Inactive</th>
                  <th>Actions</th>
                  </tr>
                </thead> 
                <tbody>
                  #{
                    _(users).map (user) ->
                      "
                      <tr>
                        <td class='mdl-data-table__cell--non-numeric'>#{user._id.substring(5)}</td>
                        <td class='mdl-data-table__cell--non-numeric'>#{user.password}</td>
                        <td class='mdl-data-table__cell--non-numeric'>#{user.district}</td>
                        <td class='mdl-data-table__cell--non-numeric'>#{user.name}</td>
                        <td class='mdl-data-table__cell--non-numeric'>#{user.roles}</td>
                        <td class='mdl-data-table__cell--non-numeric'>#{user.comments}</td>
                        <td class='mdl-data-table__cell--non-numeric'>#{user.inactive}</td>
                        <td> <button class='mdl-button mdl-js-button mdl-button--icon'>
                           <button class='edit mdl-button mdl-js-button mdl-button--icon'>
                           <a href='#' class='user-edit' data-user-id='#{user._id}'><i class='material-icons icon-24'>mode_edit</i></a></button>
                           <button class='delete mdl-button mdl-js-button mdl-button--icon'>
                           <a href='#' class='user-delete' data-user-id='#{user._id}'><i class='material-icons icon-24'>delete</i></a></button>
                        </td>
                     </tr> 
                     "
                    .join("")
                  }
                </tbody>
              </table>
            </div>
        "
        $("table.summary").tablesorter({sortList: [[0,0]]})

module.exports = UsersView
