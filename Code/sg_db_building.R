# Load Packages ####
library(DBI)

#Create new database
sg_db <- dbConnect(RSQLite::SQLite(), "sg.db")

#Sending queries to the database
dbExecute(sg_db, "CREATE TABLE pellet_survey (
          global_id,
          plot_id varchar(5) NOT NULL,
          surveyor,
          state varchar(2) CHECK (state IN ('Idaho', 'Utah')),
          date,
          type char (1) CHECK (type IN ('B','C')),
          elevation char (4),
          fire_year char (4),
          PRIMARY KEY (plot_id)
          );")

pellet_surv <- read.csv("pellet_survey.csv")
names(pellet_surv)

#Enter data from CSV into table
dbWriteTable(sg_db, "pellet_survey", pellet_surv, append = TRUE)

#check data
dbGetQuery(sg_db, "SELECT * FROM pellet_survey LIMIT 10;")

#Create table for pellet count data
dbExecute(sg_db, "CREATE TABLE pellet_count (
          unique_id PRIMARY KEY NOT NULL,
          global_id,
          pellet_type varchar (15),
          age varchar (8),
          pellet_dist varchar (5),
          dist_to_edge varchar (5),
          date,
          transect_dist varchar (5),
          hab_type varchar (20)
          );")

#Bring in pellets data
pellets <- read.csv("_pelletdata_1.csv")

dbWriteTable (sg_db, "pellet_count", pellets, append = TRUE)

dbGetQuery (sg_db, "SELECT * FROM pellet_count LIMIT 15;")

#Bring in dog data
dbExecute(sg_db, "CREATE TABLE dog_plots (
          obs_id PRIMARY KEY,
          plot_id varchar (5),
          hens varchar (2),
          chicks varchar (2),
          males varchar (2),
          chukar varchar (2),
          huns varchar (2),
          type char (1),
          distance varchar(5),
          fire_year char(4),
          elevation char(4)
          );")

dog <- read.csv("dog.csv")

dbWriteTable(sg_db, "dog_plots", dog, append = TRUE)

dbGetQuery (sg_db, "SELECT * FROM dog_plots LIMIT 10;")

#Combine pellet counts with pellet survey data
dbExecute(sg_db, "CREATE TABLE pellet_combined (
observation INTEGER PRIMARY KEY,
global_id,
plot_id varchar(5),
type char(1),
elevation char (4),
fire_year char(4),
pellet_type,
age,
pellet_dist,
dist_to_edge,
transect_dist,
hab_type,
FOREIGN KEY (global_id) REFERENCES pellet_survey(global_id)
FOREIGN KEY (global_id) REFERENCES pellet_count(global_id)
);")

dbExecute(sg_db, "INSERT INTO pellet_combined (
global_id, plot_id, type, elevation, fire_year,pellet_type, age, pellet_dist,
dist_to_edge, transect_dist, hab_type)
SELECT
pellet_survey.global_id,
pellet_survey.plot_id,
pellet_survey.type,
pellet_survey.elevation,
pellet_survey.fire_year,
pellet_count.pellet_type,
pellet_count.age,
pellet_count.pellet_dist,
pellet_count.dist_to_edge,
pellet_count.transect_dist,
pellet_count.hab_type
FROM pellet_survey LEFT JOIN pellet_count USING (global_id)
WHERE pellet_survey.global_id = pellet_count.global_id
;")

dbGetQuery (sg_db, "SELECT * FROM pellet_combined LIMIT 10;")

#delte
#dbExecute (sg_db, "DROP TABLE IF EXISTS dog_plots")
#dbExecute (sg_db, "DROP TABLE IF EXISTS pellet_survey")
#dbExecute (sg_db, "DROP TABLE IF EXISTS pellet_count")
#dbExecute (sg_db, "DROP TABLE IF EXISTS pellet_combined")
