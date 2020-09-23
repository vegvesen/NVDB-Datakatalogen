vot=5
kommune=3403


localPath = "C:\\DATA\\GitHub\\vegvesen\\NVDB-Datakatalogen\\nvdb2owl"
#proxies = {}
proxies = {'http': 'http://proxy.vegvesen.no:8080'}

url = "http://rdfspatial.vegdata.no:7200/repositories/nvdb"
# url = "http://localhost:7200/repositories/nvdb"
nvdbVoPath = "http://rdf.vegdata.no/nvdb/vegobjekt#"
nvdbVnPath = "http://rdf.vegdata.no/nvdb/vegnett#"
nvdbOTLPath = "http://rdf.vegdata.no/nvdb/nvdb-owl#"


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
               SELECT DISTINCT ?uri ?nvdb_id ?label
               WHERE {
                ?class rdfs:subClassOf+ nvdb:Vegobjekttype .
                ?class nvdb:nvdb_id """ + vot_id + """ .
                ?uri rdfs:domain ?class .
                ?uri nvdb:nvdb_id ?nvdb_id .
                ?uri rdfs:label ?label .
                }"""
    r = requests.get(url, params = {"Accept": "application/json", 'query': query}, proxies=proxies)
    #print(r.json())
    return r

def get_nvdb_enum(vot_id):
    # SPARQL-oppslag på enumerations for en objekttype
    query = """PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
               PREFIX nvdb: <http://rdf.vegdata.no/nvdb/nvdb-owl#>
               PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
               SELECT DISTINCT ?uri ?property_id ?enum_id
               WHERE {
                ?class rdfs:subClassOf+ nvdb:Vegobjekttype .
                ?class nvdb:nvdb_id """ + vot_id + """ .
                ?property rdfs:domain ?class .
    			?property rdfs:range ?codelist_uri .
    			?property nvdb:nvdb_id ?property_id .
    			?uri rdf:type ?codelist_uri .
        		?uri nvdb:nvdb_id ?enum_id .       
    			}"""
    r = requests.get(url, params = {"Accept": "application/json", 'query': query}, proxies=proxies)
    return r

# *********************************
# Her begynner selve moroa!
import sys, requests
if not [k for k in sys.path if localPath in k]:
    print('Føyer', localPath, 'til søkestien')
    sys.path.append(localPath)
from nvdbapiv3 import nvdbFagdata

# Setter opp søket
sokeobjekt = nvdbFagdata(vot)
sokeobjekt.filter( {'kommune' : kommune }) # Hamar kommune

from rdflib import Graph, Namespace, URIRef, BNode, Literal
from rdflib.namespace import RDF, RDFS, FOAF, XSD


if isinstance(sokeobjekt, nvdbFagdata):

    lagnavn = sokeobjekt.objektTypeDef['navn']
    # Initierer graf
    g = Graph()
    nvdb_ns_vo = Namespace(nvdbVoPath)
    nvdb_ns_otl = Namespace(nvdbOTLPath)
    g.bind("nvdb_vo", nvdb_ns_vo)
    g.bind("nvdb_otl",nvdb_ns_otl)
    g.bind("gsp",'http://www.opengis.net/ont/geosparql#')
    # Leser NVDB-ontologien
    print('Leser inn NVDB-OTL')
    g.parse("https://raw.githubusercontent.com/vegvesen/NVDB-Datakatalogen/master/OWL/nvdb-owl.ttl",format="turtle")

    # Oppslag i NVDB-OTL (SPAQRL) etter uri og navn for objekttypen
    print('Oppslag i NVDB-OTL (SPAQRL) etter uri og navn for objekttypen')
    sqres = get_nvdb_ft(str(sokeobjekt.objektTypeDef['id']))

    # Henter ut sosinavn og uri fra resultatet
    for result in sqres.json()["results"]["bindings"]:
        sosinavn = result["sosinavn"]["value"]
        sosinavn.encode(encoding='utf-8', errors='strict')
        uri = result["uri"]["value"]

    classURI = URIRef(uri)
    # Endre objekttypenavn
    print("Setter lagnavn: " + sosinavn + " (" + uri + ")")
    lagnavn = sosinavn

    # Slå opp egenskaps-uri-er og enum-uri-er i NVDB-OT (SPARQL)
    print('Oppslag i NVDB-OTL (SPARQL) på egenskaper')
    sqresEgenskaper = get_nvdb_pt(str(sokeobjekt.objektTypeDef['id']))
    print('Oppslag i NVDB-OTL (SPARQL) på tillatte verdier')
    sqresEnums = get_nvdb_enum(str(sokeobjekt.objektTypeDef['id']))


    objektet = sokeobjekt.nesteForekomst()
    count = 0
    while objektet:
        #print(objektet)
        count += 1
        # Legger objektet inn i grafen
        objectURI = URIRef(nvdbVoPath + str(objektet['id']))
        g.add((objectURI, RDF.type, classURI))
        g.add((objectURI, URIRef(nvdbOTLPath + 'nvdb_id'), Literal(objektet['id'], datatype=XSD.integer)))

        # Prosessering av egenskaper!
        for egenskapen in objektet['egenskaper']:

            # Legger til assosiasjoner i grafen
            if str(egenskapen['navn']).startswith('Assosierte'):
                for assosiasjonen in egenskapen['innhold']:
                    egenskapURI=''
                    for result in sqresEgenskaper.json()["results"]["bindings"]:
                        if 200000 + int(result["nvdb_id"]["value"]) == int(assosiasjonen['id']):
                            egenskapURI = result["uri"]["value"]
                            g.add((objectURI, URIRef(egenskapURI), URIRef(nvdbVoPath + str(assosiasjonen['verdi']))))

            # Slå opp egenskaps-uri i NVDB-OT (SPARQL)
            egenskapURI = ''
            for result in sqresEgenskaper.json()["results"]["bindings"]:
                if int(result["nvdb_id"]["value"]) == int(egenskapen['id']):
                    egenskapURI = result["uri"]["value"]
                    #Legger til egenskap i grafen, med primitiv datatype

                    # TODO: Håndtering av egenskapstyper er ikke komplett
                    if str(egenskapen['egenskapstype']) == 'Heltall':
                        g.add((objectURI, URIRef(egenskapURI), Literal(egenskapen['verdi'], datatype=XSD.integer)))
                    elif str(egenskapen['egenskapstype']) == 'Flyttall':
                        g.add((objectURI, URIRef(egenskapURI), Literal(egenskapen['verdi'], datatype=XSD.double)))
                    elif str(egenskapen['egenskapstype']) == 'Tekst':
                        g.add((objectURI, URIRef(egenskapURI), Literal(egenskapen['verdi'], datatype=XSD.string)))
                    elif str(egenskapen['egenskapstype']) == 'Dato':
                        g.add((objectURI, URIRef(egenskapURI), Literal(egenskapen['verdi'], datatype=XSD.date)))
                    elif str(egenskapen['egenskapstype']) == 'Kortdato': # Kortdato håndteres som string
                        g.add((objectURI, URIRef(egenskapURI), Literal(egenskapen['verdi'], datatype=XSD.string)))
                    elif str(egenskapen['datatype']) == 'Flerverdiattributt, Tall' or str(egenskapen['datatype']) == 'FlerverdiAttributt, Tekst': #Enum, skal hentes fra  enuminstans
                        for enumResult in sqresEnums.json()["results"]["bindings"]:
                            if int(enumResult["property_id"]["value"]) == int(egenskapen['id']) \
                                    and int(enumResult["enum_id"]["value"]) == int(egenskapen['enum_id']):
                                enumUri = URIRef(str(enumResult["uri"]["value"]))
                                g.add((objectURI, URIRef(egenskapURI), enumUri))
                    elif str(egenskapen['egenskapstype']) == 'Geometri':
                        # Geometriegenskaper - setter alt som "Geometri nå.
                        # Ontologien skiller mellom Punkt, Kurve og Flate
                        # egenskapen['datatype']) == 'GeomPunkt' --> Punkt
                        # egenskapen['datatype']) == 'GeomLinje eller Kurve' --> Kurve
                        # egenskapen['datatype']) == 'GeomFlate' --> Flate
                        # Andre --> Geometri

                        # Lager geometriobjekt og geometriproperty.
                        # Geometriobjektet brukes også for den generelle stedfestingen lenger ned.
                        # Refererer da objektet sin geometrirepresentasjon til samme geometriobjekt som i objektets geometriegenskap
                        geomURI = URIRef(nvdbVoPath + str(objektet['id']) + '_' + str(egenskapen['id']))
                        g.add((objectURI, URIRef(egenskapURI), geomURI))
                        g.add((geomURI, RDFS.label, Literal(str(objektet['id']) + ' Egengeometri')))

                        #TODO: Geometriegenskaper referert til SKOS-konsepter fra skjema.geonorge.no
                        if 'høydereferanse' in egenskapen:
                            g.add((geomURI, URIRef(nvdbOTLPath + 'høydereferanse'), Literal(egenskapen['høydereferanse'], datatype=XSD.string)))
                        if 'medium' in egenskapen:
                            g.add((geomURI, URIRef(nvdbOTLPath + 'medium'), Literal(egenskapen['medium'], datatype=XSD.string)))

                        if 'kvalitet' in egenskapen:
                            for kvaliteten in egenskapen['kvalitet']:
                                if 'målemetode' in kvaliteten:
                                    g.add((geomURI, URIRef(nvdbOTLPath + 'målemetode'), Literal(egenskapen['kvalitet']['målemetode'])))
                                if 'målemetodeHøyde' in kvaliteten:
                                    g.add((geomURI, URIRef(nvdbOTLPath + 'målemetodeHøyde'), Literal(egenskapen['kvalitet']['målemetodeHøyde'])))
                                if 'nøyaktighet' in kvaliteten:
                                    g.add((geomURI, URIRef(nvdbOTLPath + 'nøyaktighet'), Literal(egenskapen['kvalitet']['nøyaktighet'])))
                                if 'nøyaktighetHøyde' in kvaliteten:
                                    g.add((geomURI, URIRef(nvdbOTLPath + 'nøyaktighetHøyde'), Literal(egenskapen['kvalitet']['nøyaktighetHøyde'])))
                                if 'synbarhet' in kvaliteten:
                                    g.add((geomURI, URIRef(nvdbOTLPath + 'synbarhet'), Literal(egenskapen['kvalitet']['synbarhet'])))
                                if 'maksimaltAvvik' in kvaliteten:
                                    g.add((geomURI, URIRef(nvdbOTLPath + 'maksimaltAvvik'),Literal(egenskapen['kvalitet']['maksimaltAvvik'])))
                    else:
                        print('Annen egenskapstype: ', egenskapen)
                        g.add((objectURI, URIRef(egenskapURI), Literal(egenskapen['verdi'], datatype=XSD.string)))

        if 'geometri' in objektet:
           #TODO: SRID i WKT-strengen
           if str(objektet['geometri']['egengeometri']) == 'False':
               # Lager nytt geometriobjekt med geometri avledet fra vegnett
               geomURI = URIRef(nvdbVoPath + str(objektet['id']) + '_lrGeo')
               g.add((geomURI, RDFS.label, Literal(str(objektet['id']) + ' Geometri avledet fra vegnett')))

           #Knytter geometriobjektet til objektet
           g.add((objectURI, URIRef(nvdbOTLPath + 'geometriposisjon'), geomURI))
           g.add((geomURI, RDF.type, URIRef(nvdbOTLPath + 'Geometri')))
           g.add((geomURI, URIRef('http://www.opengis.net/ont/geosparql#asWKT'), Literal(objektet['geometri']['wkt'])))
           g.add((geomURI, URIRef(nvdbOTLPath + 'egengeometri'), Literal(objektet['geometri']['egengeometri'], datatype=XSD.boolean)))

        if 'stedfestinger' in objektet['lokasjon']:
           lrCount=0
           for stedfestingen in objektet['lokasjon']['stedfestinger']:
               #print(stedfestingen)
               lrCount += 1
               #Definer objekt med type http://rdf.vegdata.no/nvdb/nvdb-owl#LineærPosisjonPunkt eller http://rdf.vegdata.no/nvdb/nvdb-owl#LineærPosisjonStrekning
               lrURI = URIRef(nvdbVoPath + str(objektet['id']) + '_lr' + str(lrCount))
               if str(stedfestingen['type']) == 'Punkt':
                   g.add((lrURI, RDF.type, URIRef(nvdbOTLPath + 'LineærPosisjonPunkt')))
                   g.add((lrURI, URIRef(nvdbOTLPath + 'påPosisjon'),Literal(stedfestingen['relativPosisjon'], datatype=XSD.double)))
               else:
                   g.add((lrURI, RDF.type, URIRef(nvdbOTLPath + 'LineærPosisjonStrekning')))
                   g.add((lrURI, URIRef(nvdbOTLPath + 'fraPosisjon'),Literal(stedfestingen['startposisjon'], datatype=XSD.double)))
                   g.add((lrURI, URIRef(nvdbOTLPath + 'tilPosisjon'),Literal(stedfestingen['sluttposisjon'], datatype=XSD.double)))

               g.add((lrURI, RDFS.label, Literal(str(objektet['id']) + ' Lineær posisjon' + '_' + str(lrCount))))
               g.add((lrURI, URIRef(nvdbOTLPath + 'lrposNettverkselement'), URIRef(nvdbVnPath + str(stedfestingen['veglenkesekvensid']))))
               g.add((lrURI, URIRef(nvdbOTLPath + 'lineærReferansemetode'), URIRef(nvdbOTLPath + 'lrmNormalisert')))

               if 'retning' in stedfestingen:
                   g.add((lrURI, URIRef(nvdbOTLPath + 'lrRetning'), Literal(stedfestingen['retning'], datatype=XSD.string)))
               if 'sideposisjon' in stedfestingen:
                   g.add((lrURI, URIRef(nvdbOTLPath + 'lrSideposisjon'), Literal(stedfestingen['sideposisjon'], datatype=XSD.string)))

               #Koble den lineære posisjonen til objektet
               g.add((objectURI, URIRef(nvdbOTLPath + 'lrposisjon'), lrURI))

        if count % 100 == 0 or count in [1, 10, 20, 50]:
            print('Prosessert ', count, 'av', sokeobjekt.antall, 'NVDB-objekter av objekttypen ', lagnavn)

        objektet = sokeobjekt.nesteForekomst()

    print('Prosessert ', count, 'av', sokeobjekt.antall, 'NVDB-objekter av objekttypen ', lagnavn)

    # Lister grafen
    #print(g.serialize(format="turtle").decode())
    # Skriver til fil (turtle)
    print('Skriver til turtle-fil')
    g.serialize(destination=localPath + "\\data\\" + str(kommune) + "_" + lagnavn + ".ttl", format="turtle")

print('Ferdig')
