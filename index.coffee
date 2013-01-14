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
scriptPath = "https://#{nickname}.koding.com/.applications/pdfviewer/app/pdf.js"

#pdfFileName = "http://kankartali.com/go.pdf"
#pdfFileName = "http://kankartali.com/sample.pdf"
#pdfFileName = "https://#{nickname}.koding.com/.applications/pdfviewer/sample.pdf"
#pdfFileName = "/Users/#{nickname}/Applications/PDFViewer.kdapp/sample.pdf"
pdfFileName = "/Users/#{nickname}/Applications/PDFViewer.kdapp/go.pdf"
#pdfFileName = "/Users/#{nickname}/Applications/Sample.kdapp/index.coffee"
#pdfFileName = "/Users/#{nickname}/Applications/PDFViewer.kdapp/resources/pdf.128.png"

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
    constructor: (@canvasId = "canvasView") ->
        super null
    
    partial: -> 
    pistachio: ()->
        "
        <div class='canvasContainer'>
            <canvas id='#{@canvasId}'></canvas>
        </div>
        "
  
    viewAppended: () ->
        @setTemplate do @pistachio



#Main app view
class PDFViewerApp extends KDView
    viewAppended:->
        super
        
        scriptInjector = new ScriptInjector {tagName:'span'}
        @addSubView scriptInjector
        
        canvasInjector = new CanvasInjector "canvasView"
        
        headerView = new KDHeaderView
            type: "big"
            title: pdfTitle
        
        previousPageButton = new KDButtonView
            cssClass    : "clean-gray index-input"
            title       : "<"
            callback    : ->
                renderPage currentIndex - 1, "canvasView", 1
                indexView.setValue(currentIndex)
        
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
                renderPage currentIndex + 1, "canvasView", 1
                indexView.setValue(currentIndex)
        
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
        
        for thumbnailPage in [1..pageCount]
            thumbnail = new CanvasInjector "thumbnail#{thumbnailPage}"
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
            renderPage 1, "canvasView", 1
            headerView.title = pdfTitle
            indexView.setValue(currentIndex)
            pageCountView.setValue(pageCount)
            
            for thumbnailPage in [1...pageCount]
                renderPage thumbnailPage, "thumbnail#{thumbnailPage}", 0.25
            


#Renders the page with the given index.
renderPage = (pageNo, canvasId = "canvasView", scale = 1.0) ->
    KD.log "Rendering page #{pageNo}."
    
    try
        if pageNo > pageCount or pageNo == 0
            KD.log "Requested index is out of bounds."
            return
        
        currentIndex = pageNo
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
renderPdf = (fileName) ->
    KD.log "Initializing document."
    
    if disableWorker
        KD.log "Disabling PDFJS worker"
    pdfRenderer.disableWorker = disableWorker
    
    try
        KD.log "Fetching file: #{pdfFileName}"
        file = FSHelper.createFileFromPath(pdfFileName)
        file.fetchContents (error, content)->
            #At this point, the binary file isn't received via wss:// due to invalid UTF-8 characters.
            if error
                KD.log "File fetch error: #{error}"
            else
                KD.log "File fetched"
				
                #If the file being fetched is a plain-text file, it can be seen on the console here.
                #KD.log "File content: #{content}"
                
                #TODO: Fix the WSS binary UTF-8 problem, remove the return keyword, and start working on rendering the file fetched directly from stream.
                return
				
                pdfRenderer.getDocument(content).then (pdf) ->
                    KD.log "Read PDF document:"
                    KD.log pdf
                    
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
                    KD.log "PDF title: #{pdfTitle}"
                    appView.addSubView new PDFViewerApp
                
    catch error
        message = "ERROR: Type:[#{error.type}], Message:[#{error.message}]"
        notify message
        

notify = (message) ->
    KD.log message
    new KDNotificationView
        title : message


#Instantiate the app.
do ->
    KD.log "Initializing app."
    #getFile(pdfFileName)
    
    try
        if pdfRenderer is undefined or pdfRenderer is null or pdfRenderer is ""
            notify "pdfRenderer is undefined."
            return
        
        renderPdf(pdfFileName)
        
    catch error
        notify error

