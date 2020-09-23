import sys, requests,datetime
from rdflib import Graph, Namespace, URIRef, BNode, Literal
from rdflib.namespace import RDF, RDFS, FOAF, XSD


vot=5

proxies = {'http': 'http://proxy.vegvesen.no:8080'}
url = "http://rdfspatial.vegdata.no:7200/repositories/nvdb"

def get_nvdb_ft(vot_id):
    # SPARQL-oppslag på en vegobjekttype
    query = """PREFIX nvdb: <http://rdf.vegdata.no/nvdb/nvdb-owl#>
                SELECT DISTINCT ?uri ?sosinavn
                WHERE {
                ?uri rdfs:subClassOf+ nvdb:Vegobjekttype .
                ?uri nvdb:nvdb_id """ + vot_id + """ .
                ?uri nvdb:sosi_navn ?sosinavn .}"""
    r = requests.get(url, params={"Accept": "application/json", 'query': query}, proxies=proxies)
    return r

def get_nvdb_pt(vot_id):
    # SPARQL-oppslag på egenskapstyper for en objekttype
    query = """PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
               PREFIX nvdb: <http://rdf.vegdata.no/nvdb/nvdb-owl#>
               PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
               SELECT DISTINCT ?uri ?nvdb_id ?label ?sosinavn
               WHERE {
                ?class rdfs:subClassOf+ nvdb:Vegobjekttype .
                ?class nvdb:nvdb_id """ + vot_id + """ .
                ?uri rdfs:domain ?class .
                ?uri nvdb:nvdb_id ?nvdb_id .
                ?uri rdfs:label ?label .
                ?uri nvdb:sosi_navn ?sosinavn .
                }"""
    r = requests.get(url, params={"Accept": "application/json", 'query': query}, proxies=proxies)
    return r

def get_nvdb_enum(vot_id):
    # SPARQL-oppslag på enumerations for en objekttype
    query = """PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
               PREFIX nvdb: <http://rdf.vegdata.no/nvdb/nvdb-owl#>
               PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
               SELECT DISTINCT ?uri ?property_id ?enum_id ?sosinavn
               WHERE {
                ?class rdfs:subClassOf+ nvdb:Vegobjekttype .
                ?class nvdb:nvdb_id """ + vot_id + """ .
                ?property rdfs:domain ?class .
    			?property rdfs:range ?codelist_uri .
    			?property nvdb:nvdb_id ?property_id .
    			?uri rdf:type ?codelist_uri .
        		?uri nvdb:nvdb_id ?enum_id . 
        		?uri nvdb:sosi_navn ?sosinavn .      
    			}"""
    r = requests.get(url, params={"Accept": "application/json", 'query': query}, proxies=proxies)
    return r

startTime = datetime.datetime.now()

# Oppslag i NVDB-OTL (SPAQRL) etter uri og navn for objekttypen
print(str(datetime.datetime.now()) + ' Oppslag i NVDB-OTL (SPAQRL) etter uri og navn for objekttypen')
sqres = get_nvdb_ft(str(vot))
votcnt=0
# Slå opp uri og sosinavn for vegobjekttypen
for result in sqres.json()["results"]["bindings"]:
    print(str(datetime.datetime.now()) + ' Vegobjekttype ', str(vot), ' uri: ' , result["uri"]["value"] ,' sosinavn: ', result["sosinavn"]["value"])
    votcnt+=1

# Slå opp egenskaps-uri-er og enum-uri-er i NVDB-OT (SPARQL)
print(str(datetime.datetime.now()) + ' Oppslag i NVDB-OTL (SPARQL) på egenskaper')
sqresEgenskaper = get_nvdb_pt(str(vot))
ptcnt=0
for result in sqresEgenskaper.json()["results"]["bindings"]:
    print(str(datetime.datetime.now()) + ' Egenskapstype ', result["nvdb_id"]["value"], ' uri: ' , result["uri"]["value"] ,' sosinavn: ', result["sosinavn"]["value"])
    ptcnt+=1

print(str(datetime.datetime.now()) + ' Oppslag i NVDB-OTL (SPARQL) på tillatte verdier')
sqresEnums = get_nvdb_enum(str(vot))
encnt=0
for result in sqresEnums.json()["results"]["bindings"]:
    print(str(datetime.datetime.now()) + ' Tillatt verdi ', result["enum_id"]["value"], ' uri: ' , result["uri"]["value"] ,' sosinavn: ', result["sosinavn"]["value"])
    encnt+=1

timePassed =datetime.datetime.now() - startTime
print('Antall vegobjekttyper: ', votcnt)
print('Antall egenskapstyper: ', ptcnt)
print('Antall tillatte verdier: ', encnt)
print(str(datetime.datetime.now()) + ' Tidsforbruk: ' + str(timePassed) + ')')
