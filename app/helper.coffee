
notify = (message) ->
    KD.log message
    new KDNotificationView
        title : message

doKiteRequest = (command, callback) ->
    KD.log "Performing kite request: #{command}"
    KD.getSingleton('kiteController').run command, (error, content) =>
        unless error
            callback(content) if callback
        else
            notify "An error occured while processing kite request: #{error}"
