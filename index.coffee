{nickname} = KD.whoami().profile
{
    KDView,
    KDSplitView,
    KDInputView,
    KDButtonView,
    KDCustomHTMLView,
    KDHeaderView,
    KDNotificationView,
} = KD.classes

pdfRenderer = PDFJS
base64Decoder = Base64Binary
scriptPath = "https://#{nickname}.koding.com/.applications/pdfviewer/app/pdf.js"
pdfFileName = "/Users/#{nickname}/Applications/PDFViewer.kdapp/sample.pdf"
defaultCanvas = "pdfCanvasView"

pdfFile = null
currentIndex = 0

#Set PDFJS worker source
pdfRenderer.workerSrc = scriptPath

#Is PDFJS worker disabled
disableWorker = false


#PDF information
author = ""
creator = ""
modificationDate = ""
pageCount = 0
pdfVersion = ""
producer = ""
pdfTitle = ""



#Main app view
class PDFViewerApp extends KDView

    #Javascript injector for pdf.js
    class ScriptInjector extends KDCustomHTMLView
        constructor: () ->
            super
        
        partial: -> 
        pistachio: () ->
            "
            <script type='text/javascript' src='#{scriptPath}'></script>
            "
      
        viewAppended: () ->
            @setTemplate do @pistachio
    
    #Canvas injector
    class CanvasInjector extends KDCustomHTMLView
        constructor: (@thumbPage = null) ->
            super null
            
            if @thumbPage == null or @thumbPage == undefined
                @canvasId = defaultCanvas
            else
                @canvasId = "thumbnail-#{@thumbPage}"
        
        
        partial: -> 
        pistachio: ()->
            "
            <canvas id='#{@canvasId}' class='pdfCanvas'></canvas>
            "
        
        viewAppended: () ->
            @setTemplate do @pistachio
        
        click: =>
            if @thumbPage != null
                renderPage @thumbPage
        
    
    
    indexView = null
    
    viewAppended:->
        super
        
        scriptInjector = new ScriptInjector {tagName:'span'}
        @addSubView scriptInjector
        
        canvasInjector = new CanvasInjector
            
        
        headerView = new KDHeaderView
            type: "big"
            title: pdfTitle
        
        previousPageButton = new KDButtonView
            cssClass    : "clean-gray index-input"
            title       : "<"
            callback    : ->
                renderPage currentIndex - 1, defaultCanvas, 1
        
        indexView = new KDInputView
            cssClass : "index-input"
            placeholder : "0"
            readonly    : true
        
        pageCountView = new KDInputView
            cssClass : "index-input"
            placeholder : "0"
            readonly    : true
        
        nextPageButton = new KDButtonView
            cssClass    : "clean-gray index-input"
            title       : ">"
            callback    : ->
                renderPage currentIndex + 1, defaultCanvas, 1
        
        navSplitView = new KDSplitView
            type        : "vertical"
            resizable   : no
            sizes       : ["25px", "36px", "36px", "25px"]
            views       : [previousPageButton, indexView, pageCountView, nextPageButton]
        
        topSplitView = new KDSplitView
            type        : "vertical"
            resizable   : no
            sizes       : [null, "122px"]
            views       : [headerView, navSplitView]
        
        thumbnailsView = new KDView
            cssClass    : "thumbnail-container"
        
        for thumbnailPage in [1..pageCount]
            thumbnail = new CanvasInjector thumbnailPage
            thumbnailsView.addSubView thumbnail
        
        bottomSplitView = new KDSplitView
            type        : "vertical"
            resizable   : no
            sizes       : [160, null]
            views       : [thumbnailsView, canvasInjector]
        
        mainSplitView = new KDSplitView
            type        : "horizontal"
            resizable   : no
            sizes       : ["48px", null]
            views       : [topSplitView, bottomSplitView]
        
        @addSubView mainSplitView
        KD.log "added mainSplitView"
            
        if pageCount is 0
            message = "No pages found in the document."
            notify message
        else
            renderPage 1
            headerView.title = pdfTitle
            indexView.setValue(currentIndex)
            pageCountView.setValue(pageCount)
            
            for thumbnailPage in [1..pageCount]
                renderPage thumbnailPage, "thumbnail-#{thumbnailPage}", 0.22
            

    
    #Renders the page with the given index.
    renderPage = (pageNo, canvasId = defaultCanvas, scale = 1.0) ->
        KD.log "Rendering page #{pageNo}."
        
        try
            if pageNo > pageCount or pageNo == 0
                KD.log "Requested index is out of bounds."
                return
            
            #Obviously these hacks and slashes are way too ugly. They're to be cleaned up later on.
            if canvasId == defaultCanvas
                currentIndex = pageNo
                indexView.setValue currentIndex
            
            pdfFile.getPage(pageNo).then (page) ->
                KD.log "Extracted page:"
                #KD.log page
                
                viewport = page.getViewport(scale)
                canvas = document.getElementById canvasId
                context = canvas.getContext "2d"
                canvas.height = viewport.height
                canvas.width = viewport.width
                renderContext =
                    canvasContext: context
                    viewport: viewport
                
                page.render renderContext
                
                KD.log "Render complete."
        catch error
            message = "ERROR: Type:[#{error.type}], Message:[#{error.message}]"
            KD.log message
            KD.log error
            
            modal = new KDModalView
                title: "Error"
                content: message
                height: "auto"
                overlay: yes
                buttons:
                    OK:
                        loader:
                            color: "#ffffff"
                            diameter: 16
                        style: "css-class"
                        callback: ->
                            new KDNotificationView
                                title: "Please try restarting the application."
                            modal.destroy()
            



#Invokes PDFJS in order to initialize the PDF file.
parsePdf = (fileName) ->
    KD.log "Initializing document."
    
    if disableWorker
        KD.log "Disabling PDFJS worker"
    pdfRenderer.disableWorker = disableWorker
    
    try
        KD.log "Fetching file: #{pdfFileName}"
        #file = FSHelper.createFileFromPath(pdfFileName)
        doKiteRequest "base64 #{pdfFileName}", (encodedContent) =>
        
            KD.log encodedContent
            KD.log "Decoding Base64 encoded file"
            content = base64Decoder.decodeArrayBuffer encodedContent
			
            pdfRenderer.getDocument(content).then (pdf) ->
                KD.log "Read PDF document:"
                KD.log pdf.pdfInfo.info
                
                pdfFile = pdf
                
                #Retrieve document properties.
                author = pdfFile.pdfInfo.info.Author
                creator = pdfFile.pdfInfo.info.Creator
                modificationDate = pdfFile.pdfInfo.info.ModDate
                pageCount = pdfFile.pdfInfo.numPages
                pdfVersion = pdfFile.pdfInfo.info.PDFFormatVersion
                producer = pdfFile.pdfInfo.info.Producer
                pdfTitle = pdfFile.pdfInfo.info.Title
                
                #Display the app itself
                appView.addSubView new PDFViewerApp
                
    catch error
        message = "ERROR: Type:[#{error.type}], Message:[#{error.message}]"
        notify message


#Instantiate the app.
do ->
    KD.log "Initializing app."
    
    try
        if pdfRenderer is undefined or pdfRenderer is null or pdfRenderer is ""
            notify "pdfRenderer is undefined."
            return
        
        #Parse the document and set initial values.
        parsePdf pdfFileName
        
    catch error
        notify error

