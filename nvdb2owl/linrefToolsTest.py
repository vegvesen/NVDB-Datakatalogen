import re

#file_location="C:\\DATA\\GIT\\SOSI-Vegnett\\GML\\3037\\3037\\Veglenke.gml"

def postProcessGML(file_location):
    with open(file_location, 'r') as gml:
        f = gml.read()
    f = re.sub("gml:FeatureCollection", "wfs:FeatureCollection", f)
    f = re.sub("gml:featureMember", "wfs:member", f)
    f = re.sub("gml:boundedBy", "wfs:member", f)
    f = re.sub("xmlns:gts=\"http:\/\/www.isotc211.org\/2005\/gts\"", "timeStamp=\"2019-09-03T09:55:38Z\"", f)
    f = re.sub("gml:id=.*xsi:", "xsi:", f)
    f = re.sub("xmlns:gss=\"http:\/\/www.isotc211.org\/2005\/gss", "xmlns:wfs=\"http://www.opengis.net/wfs/2.0", f)
    f = re.sub("xmlns:gsr=\"http:\/\/www.isotc211.org\/2005\/gsr\"", "numberMatched=\"unknown\"", f)
    f = re.sub("xmlns:gco=\"http:\/\/www.isotc211.org\/2005\/gco\"", "numberReturned=\"0\"", f)
    f = re.sub("xmlns:gmd=\"http:\/\/www.isotc211.org\/2005\/gmd\"", "", f)
    f = re.sub("xmlns:sc=\"http:\/\/www.interactive-instruments.de\/ShapeChange\/AppInfo\"", "", f)
    #Fjern tomme veglenkeadresser - to ulike formater i filene
    #f = re.sub("<app:adressekode/>","",f)
    #f = re.sub("<app:adressekode></app:adressekode>", "", f)
    #f = re.sub("<app:adressenavn/>","",f)
    #f = re.sub("<app:adressenavn></app:adressenavn>", "", f)
    #f = re.sub(r'(\<app:Veglenkeadresse\>)\n\s*\n(\<\/app:Veglenkeadresse\>)', "", f, flags=re.DOTALL | re.M)
    #f = re.sub(r'(\<app:veglenkeadresse\>)\n\s*\n(\<\/app:veglenkeadresse\>)', "", f, flags=re.DOTALL | re.M)
    f = re.sub(r'^\s*(\<app:veglenkeadresse\>)\n^\s*(\<app:Veglenkeadresse\>)\n^\s*(<app:adressekode></app:adressekode>)\n^\s*(<app:adressenavn></app:adressenavn>)\n^\s*(\<\/app:Veglenkeadresse\>)\n^\s*(\<\/app:veglenkeadresse\>)', "", f, flags=re.DOTALL | re.M)
    f = re.sub(r'^\s*(\<app:veglenkeadresse\>)\n^\s*(\<app:Veglenkeadresse\>)\n^\s*(<app:adressekode/>)\n^\s*(<app:adressenavn/>)\n^\s*(\<\/app:Veglenkeadresse\>)\n^\s*(\<\/app:veglenkeadresse\>)', "", f, flags=re.DOTALL | re.M)
    f = re.sub("app:", "", f)
    f = re.sub(":app", "", f)
    #Fjern blanke linjer
    f = re.sub(r"\n\s*\n", "\n", f, re.MULTILINE)
    # f = re.sub("EPSG:6173", "http://www.opengis.net/def/crs/epsg/0/6173", f)
    f = re.sub("EPSG:5973", "http://www.opengis.net/def/crs/epsg/0/5973", f)
    # f = re.sub("http://www.opengis.net/def/crs/epsg/0/6173", "http://www.opengis.net/def/crs/epsg/0/5973", f)
    f = re.sub("-999999(\.0)?", "NaN", f)
    with open(file_location, 'w') as gml:
        gml.write(f)

import glob
for f in glob.glob("C:\\DATA\\GIT\\SOSI-Vegnett\\GML\\kommune\\*.gml"):
    print(f)
    postProcessGML(f)
for f in glob.glob("C:\\DATA\\GIT\\SOSI-Vegnett\\GML\\kommune\\**\\*.gml"):
    print(f)
    postProcessGML(f)
