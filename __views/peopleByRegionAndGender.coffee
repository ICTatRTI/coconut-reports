# db:keep-people
(doc) ->
  if doc.most_recent_summary
    emit [doc.most_recent_summary.Region.toUpperCase(), doc.most_recent_summary.Sex.toUpperCase()], doc.most_recent_summary