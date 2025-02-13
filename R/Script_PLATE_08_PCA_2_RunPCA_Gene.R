#' @title Principle component analysis for gene Data
#'
#' @description Performs principle component analysis using gene expression values.
#'
#' @param MarvelObject Marvel object. S3 object generated from \code{TransformExpValues} function.
#' @param sample.ids Character strings. Specific cells to plot.
#' @param cell.group.column Character string. The name of the sample metadata column in which the variables will be used to label the cell groups on the PCA.
#' @param cell.group.order Character string. The order of the variables under the sample metadata column specified in \code{cell.group.column} to appear in the PCA cell group legend.
#' @param cell.group.colors Character string. Vector of colors for the cell groups specified for PCA analysis using \code{cell.type.columns} and \code{cell.group.order}. If not specified, default \code{ggplot2} colors will be used.
#' @param min.cells Numeric value. The minimum no. of cells expressing the gene to be included for analysis.
#' @param features Character string. Vector of \code{gene_id} for analysis. Should match \code{gene_id} column of \code{MarvelObject$GeneFeature}.
#' @param point.size Numeric value. Size of data points on reduced dimension space.
#' @param point.alpha Numeric value. Transparency of the data points on reduced dimension space. Take any values between 0 to 1. The smaller the value, the more transparent the data points will be.
#' @param point.stroke Numeric value. The thickness of the outline of the data points. The larger the value, the thicker the outline of the data points.
#' @param pcs Numeric vector. The two principal components (PCs) to plot. Default is the first two PCs.
#'
#' @return An object of class S3 containing with new slots \code{MarvelObject$PCA$Exp$Results}, \code{MarvelObject$PCA$Exp$Plot}, and \code{MarvelObject$PCA$Exp$Plot.Elbow}.
#'
#' @importFrom plyr join
#' @import methods
#' @import ggplot2
#' @importFrom grDevices hcl
#'
#' @export
#'
#' @examples
#' marvel.demo <- readRDS(system.file("extdata/data", "marvel.demo.rds", package="MARVEL"))
#'
#' # Define genes for analysis
#' gene_ids <- marvel.demo$Exp$gene_id
#'
#' # PCA
#' marvel.demo <- RunPCA.Exp(MarvelObject=marvel.demo,
#'                           sample.ids=marvel.demo$SplicePheno$sample.id,
#'                           cell.group.column="cell.type",
#'                           cell.group.order=c("iPSC", "Endoderm"),
#'                           min.cells=5,
#'                           features=gene_ids,
#'                           point.size=2
#'                           )
#'
#' # Check outputs
#' head(marvel.demo$PCA$Exp$Results$ind$coord)
#' marvel.demo$PCA$Exp$Plot

RunPCA.Exp <- function(MarvelObject, sample.ids=NULL, cell.group.column, cell.group.order=NULL, cell.group.colors=NULL,
                       features, min.cells=25,
                       point.size=0.5, point.alpha=0.75, point.stroke=0.1,
                       pcs=c(1,2)
                       ) {

    # Define arguments
    MarvelObject <- MarvelObject
    df <- MarvelObject$Exp
    df.pheno <- MarvelObject$SplicePheno
    df.feature <- MarvelObject$GeneFeature
    sample.ids <- sample.ids
    cell.group.column <- cell.group.column
    cell.group.order <- cell.group.order
    cell.group.colors <- cell.group.colors
    features <- features
    min.cells <- min.cells
    point.size <- point.size
    point.alpha <- point.alpha
    point.stroke <- point.stroke
    
    # Example arguments
    #MarvelObject <- marvel
    #df <- MarvelObject$Exp
    #df.pheno <-  MarvelObject$SplicePheno
    #df.feature <-  MarvelObject$GeneFeature
    #cell.group.column <- cell.group.column
    #cell.group.order <- NULL
    #cell.group.colors <- NULL
    #features <- gene_ids
    #min.cells <- 25
    #point.size <- 2
    #point.alpha <- 0.75
    #point.stroke <- 0.1
    
    ######################################################################
        
    # Create row names for matrix
    row.names(df) <- df$gene_id
    df$gene_id <- NULL
    
    # Rename cell group label/impute columns
    names(df.pheno)[which(names(df.pheno)==cell.group.column)] <- "pca.cell.group.label"
    
    # Subset relevant cells: overall
    if(!is.null(sample.ids[1])) {
        
        df.pheno <- df.pheno[which(df.pheno$sample.id %in% sample.ids), ]
        
    }
    
    # Subset relevant cells
        # Check if cell group order is defined
        if(is.null(cell.group.order[1])) {
            
            cell.group.order <- unique(df.pheno$pca.cell.group.label)
            
        }
    
        # Cell group
        index <- which(df.pheno$pca.cell.group.label %in% cell.group.order)
        df.pheno <- df.pheno[index, ]
        
        # Subset matrix
        df <- df[, df.pheno$sample.id]
        
    # Set factor levels
    levels <- intersect(cell.group.order, unique(df.pheno$pca.cell.group.label))
    df.pheno$pca.cell.group.label <- factor(df.pheno$pca.cell.group.label, levels=levels)

    # Subset features to reduce
    df.feature <- df.feature[which(df.feature$gene_id %in% features), ]
    df <- df[df.feature$gene_id, ]
 
    # Subset events with sufficient cells
    . <- apply(df, 1, function(x) {sum(x != 0)})
    index.keep <- which(. >= min.cells)
    df <- df[index.keep, ]
    df.feature <- df.feature[which(df.feature$gene_id %in% row.names(df)), ]
 
    # Reduce dimension
    res.pca <- FactoMineR::PCA(as.data.frame(t(df)), scale.unit=TRUE, ncp=20, graph=FALSE)
    
    # Scatterplot
        # Definition
        data <- as.data.frame(res.pca$ind$coord)
        x <- data[,pcs[1]]
        y <- data[,pcs[2]]
        z <- df.pheno$pca.cell.group.label
        maintitle <- paste(nrow(df), " genes", sep="")
        xtitle <- paste("PC1 (", round(factoextra::get_eigenvalue(res.pca)[1,2], digits=1), "%)" ,sep="")
        ytitle <- paste("PC2 (", round(factoextra::get_eigenvalue(res.pca)[2,2], digits=1), "%)" ,sep="")
        legendtitle <- "Group"
        
        # Color scheme
        if(is.null(cell.group.colors[1])) {
        
            gg_color_hue <- function(n) {
              hues = seq(15, 375, length = n + 1)
              hcl(h = hues, l = 65, c = 100)[1:n]
            }
            
            n = length(levels(z))
            cols = gg_color_hue(n)
        
        } else {
            
            cols <- cell.group.colors
            
        }
        
        # Plot
        plot <- ggplot() +
            geom_point(data, mapping=aes(x=x, y=y, fill=z), size=point.size, pch=21, alpha=point.alpha, stroke=point.stroke) +
            scale_fill_manual(values=cols) +
            labs(title=maintitle, x=xtitle, y=ytitle, fill=legendtitle) +
            theme(panel.grid.major=element_blank(),
                panel.grid.minor=element_blank(),
                panel.background=element_blank(),
                plot.title = element_text(size=12, hjust=0.5),
                axis.line=element_line(colour = "black"),
                axis.title=element_text(size=12),
                axis.text.x=element_text(size=10, colour="black"),
                axis.text.y=element_text(size=10, colour="black"),
                legend.title=element_text(size=8),
                legend.text=element_text(size=8)
                )  +
        guides(fill = guide_legend(override.aes=list(size=2, alpha=point.alpha, stroke=point.stroke), ncol=1))
  
    ######################################################################
    
    # Save to new slot
    MarvelObject$PCA$Exp$Results <- res.pca
    MarvelObject$PCA$Exp$Plot <- plot
    
    return(MarvelObject)
        
}
