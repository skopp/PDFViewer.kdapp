
notify = (message) ->
    KD.log message
    new KDNotificationView
        title : message

doKiteRequest = (command, callback) ->
    KD.log "Performing kite request: #{command}"
    KD.getSingleton('kiteController').run command, (error, content) =>
        unless error
            KD.log "Kite request performed: #{command}"
            callback(content) if callback
        else
            notify "An error occured while processing kite request: #{error}"
