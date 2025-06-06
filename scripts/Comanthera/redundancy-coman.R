#This code is indetended to run redundancy analyses, which may help define the most appropriate grid
#cell' size

#=====================================================================================================#

library(raster)
library(rgdal)

#=====================================================================================================#

#=======#
# INPUT #
#=======#

#Reading clean dataset
coman_clean <- read.csv(file = "datasets/Comanthera/coman_clean.csv", na.strings = c("", NA))

#Standardizing gen_sp column (this should not be relevant when I fix the cleaning script)
coman_clean$gen_sp <- gsub(" ", "_", coman_clean$gen_sp)

#Reading shapefiles: campos rupestres and spatial grids
cr <- readOGR("shapefiles/shapefilecamporupestre/cr.shp") #Silveira (2016)

#Projecting
crswgs84 <- CRS("+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs")
proj4string(cr) <- crswgs84

#=====================================================================================================#

#====================#
# RUNNING REDUNDANCY # 
#====================#

size <- seq(0.1, 5, 0.1)
red_median <- NULL
red_mean <- NULL
for(j in 1:length(size)){
  grid <- raster(extent(cr), resolution = c(size[j], size[j]), crs = proj4string(cr))
  gridPolygon <- rasterToPolygons(grid)
  gridPolygon$id <- 1:nrow(gridPolygon)
  intersectGridClipped <- raster::intersect(gridPolygon, cr)
  intersectGrid <- gridPolygon[gridPolygon$id %in% intersectGridClipped$id, ]
  
  #Intersecting coordinates with the cr shapefile and, then, with the spatial grids 
  coords <- coman_clean 
  coordinates(coords) <- ~ longitude + latitude
  proj4string(coords) <- crswgs84
  coords_2 <- over(coords, cr)
  coords_2$id_2 <- 1:nrow(coords_2)
  coords <- coman_clean
  coords$id_2 <- 1:nrow(coords)
  coords_2 <- coords_2 %>% filter(!is.na(ID))
  coords <- coords %>% filter(id_2 %in% coords_2$id_2)
  coords_2 <- coords 
  coordinates(coords_2) <- ~ longitude + latitude
  proj4string(coords_2) <- crswgs84
  coords_2 <- over(coords_2, intersectGrid)
  coords_2$id_2 <- 1:nrow(coords_2) 
  coords$id_2 <- 1:nrow(coords_2)
  coords_2 <- coords_2 %>% filter(!is.na(id))
  coords <- coords %>% filter(id_2 %in% coords_2$id_2)
  coords$id_grid <- coords_2$id
  
  #Data frames with all samples (all_samples) and with one sample per species per grid (one_sample)
  all_samples <- coords[ , which(colnames(coords) %in% c("gen_sp", "id_grid"))]
  one_sample <- unique(all_samples, by = c("gen_sp", "id_grid"))
  
  #Redundancy values
  redundancy <- tibble("id_grid" = unique(all_samples$id_grid), "richness" = NA, "n" = NA,
                       "redundancy" = NA)
  
  SR <- plyr::count(one_sample$id_grid)
  N <- plyr::count(all_samples$id_grid)
  
  for(i in 1:nrow(redundancy)){
    redundancy$richness[i] <- SR$freq[SR$x == redundancy$id_grid[i]]
    redundancy$n[i] <- N$freq[N$x == redundancy$id_grid[i]]
  }
  
  redundancy$redundancy <- 1-(redundancy$richness/redundancy$n)
  
  red_median[j] <- median(redundancy$redundancy)
  red_mean[j] <- mean(redundancy$redundancy)
}

redundancy <- data.frame("grid_size" = size, "median" = red_median, "mean" = red_mean)

#Saving results
write.csv(file = "results/Comanthera/redundancy.csv", redundancy, row.names = FALSE)

rm(list = ls()[-which(ls() == "redundancy")])

#=====================================================================================================#

#Loading results
redundancy <- read.csv("results/Comanthera/redundancy.csv")

#=========#
# FIGURES #
#=========#

library(ggplot2)

#Median
redMedian_plot <- ggplot(data = redundancy, mapping = aes(x = grid_size, y = median)) + 
  geom_point() +
  geom_segment(data = redundancy[which(redundancy$grid_size == 0.6), ], aes(xend=grid_size), yend=-1,  #alpha = 0.5,
               linetype = "dashed") +
  geom_segment(data = redundancy[which(redundancy$grid_size == 0.6), ], aes(yend=median), xend=-1, #alpha = 0.5,
               linetype = "dashed") +
  labs(title = "Comanthera")+
  labs(y= "Redundancy", x = "Grid resolution")+
  theme_bw(base_size = 14)+
  theme(plot.title = element_text(face = "italic"), axis.text.x = element_text(angle = 0))
png("plots/Comanthera/redundancy/redMedian_plot.png",
   height = 4, width = 4, units = 'in', res=300); redMedian_plot; dev.off()


#Mean
redMean_plot <- ggplot(data = redundancy, mapping = aes(x = grid_size, y = mean)) + 
  geom_point() +
  labs(title = "Comanthera")+
  labs(y= "Redundancy (mean)", x = "Grid resolution (DD X DD)")+
  theme_bw()+
  theme(plot.title = element_text(face = "italic"))
png("plots/Comanthera/redundancy/redMean_plot.png",
   height = 4, width = 4, units = 'in', res=300); redMean_plot; dev.off()
