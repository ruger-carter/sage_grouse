# Load Packages ####
library(DBI)
library(RSQLite)
library(tidyverse)
library(patchwork)
library(viridis)

#Create new sage_grouse database
sg_db <- dbConnect(RSQLite::SQLite(), "sg.db")

#create sg_fire_plots table
dbExecute(sg_db, "CREATE TABLE sg_fire_plots (
          global_id,
          plot_id varchar(5) NOT NULL,
          state varchar(2) CHECK (state IN ('Idaho', 'Utah')),
          date,
          type char (1) CHECK (type IN ('B','C')),
          elevation char (4),
          fire_year char (4),
          surveyor,
          PRIMARY KEY (plot_id)
          );")
#bring in csv of plot data
sg_fire_plots <- read.csv("../Data/raw_data/sg_fire_plots.csv")
names(sg_fire_plots)

#Enter data from CSV into table
dbWriteTable(sg_db, "sg_fire_plots", sg_fire_plots, append = TRUE)

#check data
dbGetQuery(sg_db, "SELECT * FROM sg_fire_plots LIMIT 10;")

#Create table for pellet count data
dbExecute(sg_db, "CREATE TABLE pellet_count_raw (
          obs_id PRIMARY KEY NOT NULL,
          global_id,
          pellet_type varchar (15),
          pellet_age varchar (8),
          pellet_dist varchar (5),
          dist_to_edge varchar (5),
          transect_dist varchar (5),
          hab_type varchar (20)
          );")

#Bring in pellets data
pellet_count_raw <- read.csv("../Data/raw_data/pellet_raw.csv")

dbWriteTable (sg_db, "pellet_count_raw", pellet_count_raw, append = TRUE)

dbGetQuery (sg_db, "SELECT * FROM pellet_count_raw LIMIT 15;")

#Bring in dog data
dbExecute(sg_db, "CREATE TABLE dog_transect_raw (
          obs_id PRIMARY KEY,
          plot_id varchar (5),
          obs varchar (10),
          n varchar (2),
          dist varchar (5)
          );")

dog_raw <- read.csv("../Data/raw_data/dog_raw.csv")

dbWriteTable(sg_db, "dog_transect_raw", dog_raw, append = TRUE)

dbGetQuery (sg_db, "SELECT * FROM dog_transect_raw LIMIT 10;")

#Combine pellet counts with plot data
dbExecute(sg_db, "CREATE TABLE pellet_count (
  observation INTEGER PRIMARY KEY,
  global_id,
  plot_id varchar(5),
  type char(1),
  elevation char (4),
  fire_year char(4),
  pellet_type,
  pellet_age,
  pellet_dist,
  dist_to_edge,
  transect_dist,
  hab_type,
  FOREIGN KEY (global_id) REFERENCES sg_fire_plots(global_id)
  FOREIGN KEY (global_id) REFERENCES pellet_count_raw(global_id)
  );")

dbExecute(sg_db, "INSERT INTO pellet_count (
global_id, plot_id, type, elevation, fire_year,pellet_type, pellet_age, 
  pellet_dist,dist_to_edge, transect_dist, hab_type)
    SELECT
    sg_fire_plots.global_id,
    sg_fire_plots.plot_id,
    sg_fire_plots.type,
    sg_fire_plots.elevation,
    sg_fire_plots.fire_year,
    pellet_count_raw.pellet_type,
    pellet_count_raw.pellet_age,
    pellet_count_raw.pellet_dist,
    pellet_count_raw.dist_to_edge,
    pellet_count_raw.transect_dist,
    pellet_count_raw.hab_type
    FROM sg_fire_plots LEFT JOIN pellet_count_raw USING (global_id)
    WHERE sg_fire_plots.global_id = pellet_count_raw.global_id
    ;")

dbGetQuery (sg_db, "SELECT * FROM pellet_count LIMIT 10;")

#Combine plot data with dog data 
dbExecute(sg_db, "CREATE TABLE dog_transect (
  observation INTEGER PRIMARY KEY,
  plot_id varchar(5),
  type,
  fire_year,
  elevation,
  obs,
  n,
  dist,
  FOREIGN KEY (plot_id) REFERENCES sg_fire_plots (plot_id)
  FOREIGN KEY (plot_id) REFERENCES dog_transect_raw (plot_id)
  );")

dbExecute(sg_db, "INSERT INTO dog_transect (
plot_id, type, fire_year, elevation, obs, n, dist)
    SELECT
    sg_fire_plots.plot_id,
    sg_fire_plots.type,
    sg_fire_plots.fire_year,
    sg_fire_plots.elevation,
    dog_transect_raw.obs,
    dog_transect_raw.n,
    dog_transect_raw.dist
    FROM sg_fire_plots RIGHT JOIN dog_transect_raw USING (plot_id)
    WHERE sg_fire_plots.plot_id = dog_transect_raw.plot_id
    ;")

dbGetQuery (sg_db, "SELECT * FROM dog_transect;")
dog_transects <- dbGetQuery(sg_db, "SELECT * FROM dog_transect;")

# Let's look at bird's detected in burned and unburned plots.

dbListTables(sg_db)

dog_transects %>%
  group_by(obs, type) %>% 
  summarize(nsum = sum(n))


dbRemoveTable(sg_db, "sg_fire_plots")
dbRemoveTable(sg_db, "dog_transect_raw")
dbRemoveTable(sg_db, "pellet_count_raw")
dbRemoveTable(sg_db, "pellet_count")
dbRemoveTable(sg_db, "dog_transect")
dbListTables(sg_db)
