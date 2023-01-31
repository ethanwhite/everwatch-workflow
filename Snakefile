import glob
import os

ORTHOMOSAICS = glob_wildcards("/blue/ewhite/everglades/orthomosaics/{year}/{site}/{flight}.tif")
FLIGHTS = ORTHOMOSAICS.flight
SITES = ORTHOMOSAICS.site
YEARS = ORTHOMOSAICS.year

rule all:
    input:
        "/blue/ewhite/everglades/EvergladesTools/App/Zooniverse/data/PredictedBirds.zip",
        "/blue/ewhite/everglades/EvergladesTools/App/Zooniverse/data/nest_detections_processed.zip",
        expand("/blue/ewhite/everglades/predictions/{year}/{site}/{flight}_projected.shp",
               zip, site=SITES, year=YEARS, flight=FLIGHTS),
        expand("/blue/ewhite/everglades/processed_nests/{year}/{site}/{site}_{year}_processed_nests.shp",
               zip, site=SITES, year=YEARS),
        expand("/blue/ewhite/everglades/mapbox/{year}/{site}/{flight}.mbtiles",
               zip, site=SITES, year=YEARS, flight=FLIGHTS)


rule project_mosaics:
    input:
        "/blue/ewhite/everglades/orthomosaics/{year}/{site}/{flight}.tif"
    output:
        "/blue/ewhite/everglades/projected_mosaics/{year}/{site}/{flight}_projected.tif",
        "/blue/ewhite/everglades/projected_mosaics/webmercator/{year}/{site}/{flight}_projected.tif"
    shell:
        "python project_orthos.py {input}"

rule predict_birds:
    input:
        "/blue/ewhite/everglades/projected_mosaics/{year}/{site}/{flight}_projected.tif"
    output:
        "/blue/ewhite/everglades/predictions/{year}/{site}/{flight}_projected.shp"
    resources:
        gpu=1
    shell:
        "python predict.py {input}"

rule combine_predicted_birds:
    input:
        expand("/blue/ewhite/everglades/predictions/{year}/{site}/{flight}_projected.shp",
               zip, site=SITES, year=YEARS, flight=FLIGHTS)
    output:
        "/blue/ewhite/everglades/EvergladesTools/App/Zooniverse/data/PredictedBirds.zip"
    shell:
        "python combine_bird_predictions.py"

def flights_in_year_site(wildcards):
    basepath = "/blue/ewhite/everglades/predictions"
    flights_in_year_site = []
    for site, year, flight in zip(SITES, YEARS, FLIGHTS):
        if site == wildcards.site and year == wildcards.year:
            flight_path = os.path.join(basepath, year, site, f"{flight}_projected.shp")
            flights_in_year_site.append(flight_path)
    return flights_in_year_site

rule detect_nests:
    input:
        flights_in_year_site
    output:
        "/blue/ewhite/everglades/detected_nests/{year}/{site}/{site}_{year}_detected_nests.shp"
    shell:
        "python nest_detection.py {input}"

rule process_nests:
    input:
        "/blue/ewhite/everglades/detected_nests/{year}/{site}/{site}_{year}_detected_nests.shp"
    output:
        "/blue/ewhite/everglades/processed_nests/{year}/{site}/{site}_{year}_processed_nests.shp"
    shell:
        "python process_nests.py {input}"

rule combine_nests:
    input:
        expand("/blue/ewhite/everglades/processed_nests/{year}/{site}/{site}_{year}_processed_nests.shp",
               zip, site=SITES, year=YEARS)
    output:
        "/blue/ewhite/everglades/EvergladesTools/App/Zooniverse/data/nest_detections_processed.zip"
    shell:
        "python combine_nests.py"

rule upload_mapbox:
    input:
        "/blue/ewhite/everglades/projected_mosaics/webmercator/{year}/{site}/{flight}_projected.tif"
    output:
        "/blue/ewhite/everglades/mapbox/{year}/{site}/{flight}.mbtiles"
    shell:
        "python upload_mapbox.py {input}"
