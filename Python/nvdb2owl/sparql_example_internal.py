import sys, requests,datetime
from rdflib import Graph, Namespace, URIRef, BNode, Literal
from rdflib.namespace import RDF, RDFS, FOAF, XSD


vot=5

nvdb_otl_gh = 'https://raw.githubusercontent.com/vegvesen/NVDB-Datakatalogen/master/OWL/nvdb-owl.ttl'

def get_nvdb_ft(vot_id):
    # SPARQL-oppslag på en vegobjekttype
    query = """PREFIX nvdb: <http://rdf.vegdata.no/nvdb/nvdb-owl#>
                SELECT DISTINCT ?uri ?sosinavn
                WHERE {
                ?uri rdfs:subClassOf+ nvdb:Vegobjekttype .
                ?uri nvdb:nvdb_id """ + vot_id + """ .
                ?uri nvdb:sosi_navn ?sosinavn .}"""
    qres=otl.query(query)
    return qres

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
    qres=otl.query(query)
    return qres

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
    qres=otl.query(query)
    return qres

startTime = datetime.datetime.now()

print(str(datetime.datetime.now()) + ' Leser inn NVDB-OTL fra ', nvdb_otl_gh)
otl = Graph()
otl.parse(nvdb_otl_gh,format="turtle")

# Oppslag i NVDB-OTL (SPAQRL) etter uri og navn for objekttypen
print(str(datetime.datetime.now()) + ' Oppslag i NVDB-OTL (SPAQRL) etter uri og navn for objekttypen')
sqres = get_nvdb_ft(str(vot))
timePassedOTL =datetime.datetime.now() - startTime
print(str(datetime.datetime.now()) + ' Tidsforbruk lesing av OTL: ' + str(timePassedOTL) + ')')


votcnt=0
# Slå opp uri og sosinavn for vegobjekttypen
for row in sqres:
    print(str(datetime.datetime.now()) + ' Vegobjekttype ', str(vot), ' uri: ' , row.uri ,' sosinavn: ', row.sosinavn)
    votcnt+=1

# Slå opp egenskaps-uri-er og enum-uri-er i NVDB-OT (SPARQL)
print(str(datetime.datetime.now()) + ' Oppslag i NVDB-OTL (SPARQL) på egenskaper')
sqresEgenskaper = get_nvdb_pt(str(vot))
ptcnt=0
for row in sqresEgenskaper:
    print(str(datetime.datetime.now()) + ' Egenskapstype ', row.nvdb_id, ' uri: ' , row.uri ,' sosinavn: ', row.sosinavn)
    ptcnt+=1

print(str(datetime.datetime.now()) + ' Oppslag i NVDB-OTL (SPARQL) på tillatte verdier')
sqresEnums = get_nvdb_enum(str(vot))
encnt=0
for row in sqresEnums:
    print(str(datetime.datetime.now()) + ' Tillatt verdi ', row.enum_id, ' uri: ' , row.uri ,' sosinavn: ', row.sosinavn)
    encnt+=1

timePassed =datetime.datetime.now() - startTime
print('Antall vegobjekttyper: ', votcnt)
print('Antall egenskapstyper: ', ptcnt)
print('Antall tillatte verdier: ', encnt)
print(str(datetime.datetime.now()) + ' Tidsforbruk: ' + str(timePassed) + ')')
print(str(datetime.datetime.now()) + ' Tidsforbruk kun SPARQL: ' + str(timePassed-timePassedOTL) + ')')