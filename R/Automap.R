#' AutoMap
#'
#' Interface Shiny de creation automatique de cartes de terrain
#'
#' Basee sur la base de donnees Guyafor
#'
#' @inheritParams Guyafor2df
#'
#' @author Elie Guedj, \email{elie.guedj@ecofog.gf}
#'
#' @import svglite
#'
#' @inheritParams Guyafor2df
#' @param data Dataframe in Guyafor format
#'
#' @export
Automap <- function(data = NULL, UID = NULL, PWD = NULL, Driver="SQL Server Native Client 10.0") {

  donnerForet <- function(NomForet) { return(DataGuyafor[DataGuyafor$Forest == NomForet, ])}

  donnerCampagne <- function(foret, annee) { foret[foret$CensusYear == annee, ] }

  donnerParcelle <- function(nomParcelle, campagne){  # Choix de la parcelle
    campagne <- campagne[campagne$Plot == nomParcelle, ]
    campagne$SubPlot <- factor(campagne$SubPlot)
    return(campagne)
  }
  donnerCarre <- function(numeroCarre, parcelle) { parcelle[parcelle$SubPlot == numeroCarre, ] } # Choix du carre

  donnerAnneesParForet <- function(foret) {
    return(levels(as.factor(foret$CensusYear)))
  }

  ## Construction du graphique ##
  graphCarre <- function(carre, title, text_size = 7, title_size = 50, legend_size = 25, axis_size = 25, repel = TRUE) {

    carre$CodeAlive <- factor(carre$CodeAlive)

      if (carre$Forest[1] == "Paracou" && carre$Plot[1] != 18 && carre$Plot != 16) {
        if (carre$SubPlot[1] == 1) {
          xLim = c(0,125)
          yLim = c(125,250)
        } else if (carre$SubPlot[1] == 2) {
          xLim = c(125,250)
          yLim = c(125,250)
        } else if (carre$SubPlot[1] == 3) {
          xLim = c(0,125)
          yLim = c(0,125)
        } else if (carre$SubPlot[1] == 4) {
          xLim = c(125,250)
          yLim = c(0,125)
        }
      }

    if (repel == TRUE) {
      legende_texte <- ggrepel::geom_text_repel(size=text_size, fontface=ifelse(carre$TreeFieldNum>= 1000,"bold","plain"), force = 0.3)
    } else {
      legende_texte <- ggrepel::geom_text_repel(size=text_size, fontface=ifelse(carre$TreeFieldNum>= 1000,"bold","plain"), force = 0.001)
    }
    graph <- ggplot2::ggplot(carre, ggplot2::aes_(x = ~Xfield, y = ~Yfield, label=~TreeFieldNum)) +
      ggplot2::coord_fixed(ratio = 1) +
      ggplot2::geom_point(ggplot2::aes_(x=~Xfield, y=~Yfield, shape=~CodeAlive, size=~Circ)) +
      legende_texte +
      ggplot2::scale_shape_manual(values=c(3,16,17), name=" ", label=c("Vivant","Mort","Recrute"), breaks=c(1,0,2)) +
      ggplot2::scale_size_continuous(range = c(1, 5), name = "Vivant") +
      ggplot2::theme_bw() +
      ggplot2::ggtitle(title) +
      ggplot2::guides(shape = ggplot2::guide_legend(override.aes = list(size = 5))) +
      ggplot2::theme(axis.line = ggplot2::element_line(colour = "black"),
            panel.grid.major = ggplot2::element_blank(),
            panel.grid.minor = ggplot2::element_blank(),
            panel.border = ggplot2::element_blank(),
            panel.background = ggplot2::element_blank(),
            plot.title = ggplot2::element_text(size=title_size),
            legend.text = ggplot2::element_text(size=legend_size),
            legend.title = ggplot2::element_text(size=30),
            axis.text = ggplot2::element_text(size = axis_size),
            axis.title = ggplot2::element_text(size = axis_size+10)
      )
    if (exists("yLim") && exists("xLim")) {
      graph <- graph + ggplot2::coord_cartesian(xlim = xLim, ylim = yLim)
    }
    return(graph)
  }
  if (is.null(data)) {
    if (!exists("DataGuyafor")){
      DataGuyafor <- Guyafor2df(UID=UID, PWD=PWD, Driver=Driver)
    }
  } else {
    DataGuyafor <- data
  }

  forets <- as.vector(unique(sort(DataGuyafor$Forest)))
  campagnes <- sort(unique(DataGuyafor$CensusYear))
  carreDispo <- sort(unique(DataGuyafor$SubPlot))
  initCampagne <- donnerCampagne(foret = donnerForet(NomForet = "Paracou"), annee = 2016)
  parcelles <- sort(unique(initCampagne$Plot))

  ui <- shiny::fluidPage(
    shiny::tags$head(
      shiny::tags$style(
        shiny::HTML(".shiny-notification {
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

    shiny::titlePanel("Createur de carte auto"),

    shiny::sidebarLayout(

      shiny::sidebarPanel(

        width = 2,

        shiny::selectInput(inputId = "foret",
                    label = "Foret :",
                    choices = forets,
                    selected = "Paracou",
                    multiple = FALSE),

        shiny::selectInput(inputId = "campagne",
                    label = "Campagne :",
                    choices = campagnes,
                    selected = 2016,
                    multiple = FALSE),

        shiny::selectInput(inputId = "parcelles",
                    label = "Parcelles :",
                    choices = parcelles,
                    selected = NULL,
                    multiple = TRUE),

        shiny::numericInput(inputId = "text_size",
                     label = "Taille du texte des libelles :",
                     7),

        shiny::checkboxInput(inputId = "repel",
                      label = "Etiquetage intelligent",
                      TRUE),

        shiny::selectInput(inputId = "extension",
                    label = "Extension :",
                    choices = c("svg","png","pdf"),
                    selected = "svg",
                    multiple = FALSE),

        shiny::selectInput(inputId = "carre",
                           label = "Choix du carre pour apercu :",
                           choices = carreDispo,
                           selected = 1,
                           multiple = FALSE),

        shiny::actionButton("sauvegarder", label = "Sauvegarder"),

        shiny::actionButton("apercu", label = "Apercu")

        ),


      shiny::mainPanel(
        shiny::uiOutput('condPanel')
      )

    )
  )

  server <- function(input, output, session) {
    values <- shiny::reactiveValues()
    values$show <- FALSE

    output$condPanel <- shiny::renderUI({
      if (values$show){
        shinycssloaders::withSpinner(shiny::plotOutput("apercuGraph"))
      }
    })

    shiny::observe({
        foretChoisie <- input$foret
        dataForet<- donnerForet(foretChoisie)
        campagneChoisie <- input$campagne
        dataCampagne <- donnerCampagne(donnerForet(foretChoisie), as.integer(campagneChoisie))
        parcelles <- as.vector(unique(dataCampagne$Plot))
        shiny::updateSelectInput(session, "parcelles", label = "Parcelles :", choices = parcelles)
    })

    shiny::observeEvent(input$foret, {
      foretChoisie <- input$foret
      dataForet<- donnerForet(foretChoisie)
      campagnes <- donnerAnneesParForet(dataForet)
      shiny::updateSelectInput(session, "campagne", label = "Campagne :", choices = campagnes)
    })


    shiny::observeEvent(input$sauvegarder, {
        anneePrec <- input$anneePrec
        campagneChoisie <- input$campagne
        text_size <- input$text_size
        foretChoisie <- input$foret
        repel <- input$repel
        extension <- input$extension
        repeat {
          chooseDir <- utils::choose.dir()
          if (!is.na(chooseDir)) {
            break
          }
        }
        directoryChosen <- paste(chooseDir,"\\",sep="")
        dataCampagne <- donnerCampagne(donnerForet(foretChoisie), as.integer(campagneChoisie))
        progress <- shiny::Progress$new()
        on.exit(progress$close())
        for (i in input$parcelles){

          dataParcelle <- NULL
          dataParcelle <- donnerParcelle(i, dataCampagne)

          progress$set(message = paste("Enregistrement parcelle", i), value = 0)

          for (j in levels(dataParcelle$SubPlot)) {

            progress$inc(1/as.integer(levels(dataParcelle$SubPlot)), detail = paste("Carre", j))

            nomFichier <- paste(directoryChosen,"Parcelle_",i,"_carre_",j,"_",foretChoisie, campagneChoisie,".", extension, sep="")
            title <- paste(foretChoisie," - Parcelle ",i," - C",j)
            ggplot2::ggsave(filename=nomFichier,plot=graphCarre(donnerCarre(j, dataParcelle), title, text_size, repel = repel), width = 42, height = 29.7)
          }
        }

    })

    shiny::observeEvent(input$apercu, {
      output$apercuGraph <- shiny::renderPlot({ plot1 <- NULL })
      values$show <- TRUE
      anneePrec <- input$anneePrec
      campagneChoisie <- input$campagne
      carreChoisi <- input$carre
      text_size <- input$text_size
      foretChoisie <- input$foret
      repel <- input$repel
      dataCampagne <- donnerCampagne(donnerForet(foretChoisie), as.integer(campagneChoisie))
      title <- paste(foretChoisie," - Parcelle ",input$parcelles[1]," - C", carreChoisi)
      dataParcelle <- donnerParcelle(input$parcelles[1], dataCampagne)
      output$apercuGraph <- shiny::renderPlot({ graphCarre(donnerCarre(carreChoisi, dataParcelle), title = title, text_size = text_size-4, repel = repel)} , width = 1200, height = 1200)
      })

    output$show <- shiny::reactive({
      return(values$show)
    })

  }

  Automap <- shiny::shinyApp(ui = ui, server = server)

  shiny::runApp(Automap, port = 8080)



  print("Chargement termine, vous devez rafraichir la page ouverte pour utiliser le logiciel")
}
