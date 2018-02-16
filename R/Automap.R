#' AutoMap
#'
#' Interface Shiny de création automatique de cartes de terrain
#'
#' Basée sur la base de données Guyafor
#'
#' @author Elie Guedj, \email{elie.guedj@ecofog.gf}
#'
#' @import shiny
#' @import ggplot2
#' @import svglite
#' @importFrom ggrepel geom_text_repel
#' @importFrom shinycssloaders withSpinner
#'
#' @export
Automap <- function() {

  donnerForet <- function(NomForet) { return(DataGuyafor[DataGuyafor$Forest == NomForet, ])}

  donnerCampagne <- function(foret, annee) { foret[foret$CensusYear == annee, ] }

  donnerParcelle <- function(nomParcelle, campagne){  # Choix de la parcelle
    campagne <- campagne[campagne$Plot == nomParcelle, ]
    campagne$SubPlot <- factor(campagne$SubPlot)
    return(campagne)
  }
  donnerCarre <- function(numeroCarre, parcelle) { parcelle[parcelle$SubPlot == numeroCarre, ] } # Choix du carré

  ## Construction du graphique ##
  graphCarre <- function(carre, title, text_size = 7, title_size = 50, legend_size = 25, axis_size = 25, repel = TRUE) {

    carre$CodeAlive <- factor(carre$CodeAlive)


    if (repel == TRUE) {
      legende_texte <- geom_text_repel(size=text_size, fontface=ifelse(carre$TreeFieldNum>= 1000,"bold","plain"), force = 0.3)
    } else {
      legende_texte <- geom_text_repel(size=text_size, fontface=ifelse(carre$TreeFieldNum>= 1000,"bold","plain"), force = 0.001)
    }

    graph <- ggplot(carre, aes(x = Xfield, y = Yfield, label=TreeFieldNum)) +
      coord_fixed(ratio = 1) +
      geom_point(aes(x=Xfield, y=Yfield, shape=CodeAlive, size=Circ)) +
      legende_texte +
      scale_shape_manual(values=c(3,16,17), name=" ", label=c("Vivant","Mort","Recrute"), breaks=c(1,0,2)) +
      scale_size_continuous(range = c(1, 5), name = "Vivant") +
      theme_bw() +
      ggtitle(title) +
      guides(shape = guide_legend(override.aes = list(size = 5))) +
      theme(axis.line = element_line(colour = "black"),
            panel.grid.major = element_blank(),
            panel.grid.minor = element_blank(),
            panel.border = element_blank(),
            panel.background = element_blank(),
            plot.title = element_text(size=title_size),
            legend.text = element_text(size=legend_size),
            legend.title = element_text(size=30),
            axis.text =element_text(size = axis_size),
            axis.title =element_text(size = axis_size+10)
      )

    return(graph)
  }

  if (!exists("DataGuyafor")){
    DataGuyafor <- Guyafor2df()
  }

  forets <- as.vector(unique(sort(DataGuyafor$Forest)))
  campagnes <- sort(unique(DataGuyafor$CensusYear))
  initCampagne <- donnerCampagne(foret = donnerForet(NomForet = "Paracou"), annee = 2016)
  parcelles <- sort(unique(initCampagne$Plot))

  ui <- fluidPage(
    tags$head(
      tags$style(
        HTML(".shiny-notification {
             height: 100px;
             width: 800px;
             position:fixed;
             top: calc(50% - 50px);;
             left: calc(50% - 400px);;
             }
             "
        )
      )
    ),

    shinyjs::useShinyjs(),

    titlePanel("Createur de carte auto"),

    sidebarLayout(

      sidebarPanel(

        width = 2,

        selectInput(inputId = "foret",
                    label = "Foret :",
                    choices = forets,
                    selected = "Paracou",
                    multiple = FALSE),

        selectInput(inputId = "campagne",
                    label = "Campagne :",
                    choices = campagnes,
                    selected = 2016,
                    multiple = FALSE),

        selectInput(inputId = "parcelles",
                    label = "Parcelles :",
                    choices = parcelles,
                    selected = NULL,
                    multiple = TRUE),

        numericInput(inputId = "text_size",
                     label = "Taille du texte des libelles :",
                     7),

        checkboxInput(inputId = "repel",
                      label = "Etiquetage intelligent",
                      TRUE),

        selectInput(inputId = "extension",
                    label = "Extension :",
                    choices = c("svg","png","pdf"),
                    selected = "svg",
                    multiple = FALSE),


        actionButton("sauvegarder", label = "Sauvegarder"),
        actionButton("apercu", label = "Apercu")

        ),


      mainPanel(
        uiOutput('condPanel')
      )

    )
  )

  server <- function(input, output, session) {
    values <- reactiveValues()
    values$show <- FALSE

    output$condPanel <- renderUI({
      if (values$show){
        withSpinner(plotOutput("apercuGraph"))
      }
    })

    observe({
        campagneChoisie <- input$campagne
        foretChoisie <- input$foret
        dataCampagne <- donnerCampagne(donnerForet(foretChoisie), as.integer(campagneChoisie))
        parcelles <- as.vector(unique(dataCampagne$Plot))
        updateSelectInput(session, "parcelles", label = "Parcelles :", choices = parcelles)

    })


    observeEvent(input$sauvegarder, {
        anneePrec <- input$anneePrec
        campagneChoisie <- input$campagne
        text_size <- input$text_size
        foretChoisie <- input$foret
        repel <- input$repel
        extension <- input$extension
        directoryChosen <- paste(choose.dir(),"\\",sep="")
        dataCampagne <- donnerCampagne(donnerForet(foretChoisie), as.integer(campagneChoisie))
        progress <- shiny::Progress$new()
        on.exit(progress$close())
        for (i in input$parcelles){

          dataParcelle <- NULL
          dataParcelle <- donnerParcelle(i, dataCampagne)

          progress$set(message = paste("Enregistrement parcelle", i), value = 0)

          for (j in levels(dataParcelle$SubPlot)) {

            progress$inc(1/as.integer(levels(dataParcelle$SubPlot)), detail = paste("Carré", j))

            nomFichier <- paste(directoryChosen,"Parcelle_",i,"_carre_",j,"_",foretChoisie,campagneChoisie,".", extension, sep="")
            title <- paste(foretChoisie," - Parcelle ",i," - C",j)
            ggsave(file=nomFichier,plot=graphCarre(donnerCarre(j, dataParcelle), title, text_size, repel = repel), width = 42, height = 29.7)
          }
        }

    })

    observeEvent(input$apercu, {
      output$apercuGraph <- renderPlot({ plot1 <- NULL })
      values$show <- TRUE
      anneePrec <- input$anneePrec
      campagneChoisie <- input$campagne
      text_size <- input$text_size
      foretChoisie <- input$foret
      repel <- input$repel
      dataCampagne <- donnerCampagne(donnerForet(foretChoisie), as.integer(campagneChoisie))
      title <- paste(foretChoisie," - Parcelle ",input$parcelles[1]," - C",1)
      dataParcelle <- donnerParcelle(input$parcelles[1], dataCampagne)
      output$apercuGraph <- renderPlot({ graphCarre(donnerCarre(1, dataParcelle), title = title, text_size = text_size-4, repel = repel)} , width = 1200, height = 1200)
      })

    output$show <- reactive({
      return(values$show)
    })

  }

  shinyApp(ui = ui, server = server)
}