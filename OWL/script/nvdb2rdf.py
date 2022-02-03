# Funksjoner for konvertering fra NVDB-API til RDf-graf
# ---------------------------------------------------------------------------------------------
#Importerer biblioteker
import sys, datetime
from rdflib import Graph, Namespace, URIRef,  Literal
from rdflib.namespace import RDF, RDFS, XSD
from constants import *
if not [k for k in sys.path if localPath in k]:
    print('Føyer', localPath, 'til søkestien')
    sys.path.append(localPath)
from nvdbapiv3 import nvdbFagdata

# ---------------------------------------------------------------------------------------------
# SPARQL-oppslag på en vegobjekttype
def get_nvdb_ft(vot_id,oGraph):
    query = """PREFIX nvdb: <https://ontologi.atlas.vegvesen.no/nvdb/core/nvdb-owl#>
                SELECT DISTINCT ?uri ?sosinavn
                WHERE {
                ?uri rdfs:subClassOf+ nvdb:Vegobjekttype .
                ?uri nvdb:nvdb_id """ + vot_id + """ .
                ?uri nvdb:sosi_navn ?sosinavn .}"""
    qres=oGraph.query(query)
    return qres

# ---------------------------------------------------------------------------------------------
# SPARQL-oppslag på egenskapstyper for en objekttype
def get_nvdb_pt(vot_id,oGraph):
    query = """PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
               PREFIX nvdb: <https://ontologi.atlas.vegvesen.no/nvdb/core/nvdb-owl#>
               PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
               SELECT DISTINCT ?uri ?nvdb_id ?label
               WHERE {
                ?class rdfs:subClassOf+ nvdb:Vegobjekttype .
                ?class nvdb:nvdb_id """ + vot_id + """ .
                ?uri rdfs:domain ?class .
                ?uri nvdb:nvdb_id ?nvdb_id .
                ?uri rdfs:label ?label .
                }"""
    qres=oGraph.query(query)
    return qres

# ---------------------------------------------------------------------------------------------
# SPARQL-oppslag på enumerations for en objekttype
def get_nvdb_enum(vot_id,oGraph):
    query = """PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
               PREFIX nvdb: <https://ontologi.atlas.vegvesen.no/nvdb/core/nvdb-owl#>
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
    qres=oGraph.query(query)
    return qres

# ---------------------------------------------------------------------------------------------
def nvdb2graph(vot, kommune,oGraph):
    # Konvertering av en objekttype i en kommune fra NVDB-API til RDF i henhold til NVDB-OTL
    # ---------------------------------------------------------------------------------------------
    # Henter data fra NVDB-API
    sokeobjekt = nvdbFagdata(vot)
    sokeobjekt.filter({'kommune': kommune})
    g = Graph()
    if isinstance(sokeobjekt, nvdbFagdata):
        lagnavn = sokeobjekt.objektTypeDef['navn']
        # -------------------------------------------------------------------------------------------
        # Initierer graf
        nvdb_ns_vo = Namespace(nvdbVoPath)
        nvdb_ns_otl = Namespace(nvdbOTLPath)
        g.bind("nvdb_vo", nvdb_ns_vo)
        g.bind("nvdb_otl",nvdb_ns_otl)
        g.bind("gsp",'http://www.opengis.net/ont/geosparql#')

        # -----------------------------------------------------------------------------------------
        # Oppslag i NVDB-OTL (SPAQRL) etter uri og navn for objekttypen
        print(str(datetime.datetime.now()) + ' Oppslag i NVDB-OTL (SPAQRL) etter uri og navn for objekttypen')
        sqres=get_nvdb_ft(str(sokeobjekt.objektTypeDef['id']),oGraph)

        # Henter ut sosinavn og uri fra resultatet
        for row in sqres:
            #print(str(datetime.datetime.now()) + ' URI ', row.uri ,': sosinavn ', row.sosinavn)
            sosinavn = row.sosinavn
            uri= row.uri
        sosinavn.encode(encoding='utf-8', errors='strict')

        classURI = URIRef(uri)
        # Endre objekttypenavn
        print(str(datetime.datetime.now()) + ' Setter objekttypenavn: ' + sosinavn + ' (' + str(uri) + ')')
        lagnavn = sosinavn
        # ---------------------------------------------------------------------------------------------
        # Slå opp egenskaps-uri-er og enum-uri-er i NVDB-OT (SPARQL)
        print(str(datetime.datetime.now()) + ' Oppslag i NVDB-OTL (SPARQL) på egenskaper')
        sqresEgenskaper = get_nvdb_pt(str(sokeobjekt.objektTypeDef['id']), oGraph)
        print(str(datetime.datetime.now()) + ' Oppslag i NVDB-OTL (SPARQL) på tillatte verdier')
        sqresEnums = get_nvdb_enum(str(sokeobjekt.objektTypeDef['id']),oGraph)
        print(str(datetime.datetime.now()) + ' Oppslag i NVDB-OTL (SPARQL) fullført')

        # -------------------------------------------------------------------------------------------------
        # Løkke for prosessering av resultater
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
                        for ptRow in sqresEgenskaper:
                            if 200000 + int(ptRow.nvdb_id) == int(assosiasjonen['id']):
                                egenskapURI = ptRow.uri
                                g.add((objectURI, URIRef(egenskapURI), URIRef(nvdbVoPath + str(assosiasjonen['verdi']))))

                # Slå opp egenskaps-uri i NVDB-OT (SPARQL)
                egenskapURI = ''
                for ptRow in sqresEgenskaper:
                    if int(ptRow.nvdb_id) == int(egenskapen['id']):
                        egenskapURI = ptRow.uri
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
                            for enumRow in sqresEnums:
                                if int(enumRow.property_id) == int(egenskapen['id']) \
                                        and int(enumRow.enum_id) == int(egenskapen['enum_id']):
                                    enumUri = URIRef(str(enumRow.uri))
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
                            print(str(datetime.datetime.now()) + ' Annen egenskapstype: ', egenskapen)
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
                   #Definer objekt med type https://ontologi.atlas.vegvesen.no/nvdb/core/nvdb-owl##LineærPosisjonPunkt eller https://ontologi.atlas.vegvesen.no/nvdb/core/nvdb-owl##LineærPosisjonStrekning
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
                print(str(datetime.datetime.now()) + ' Prosessert ', count, 'av', sokeobjekt.antall, 'NVDB-objekter av objekttypen ', lagnavn)

            objektet = sokeobjekt.nesteForekomst()
        print(str(datetime.datetime.now()) + ' Prosessert ', count, 'av', sokeobjekt.antall, 'NVDB-objekter av objekttypen ', lagnavn)
    return g


