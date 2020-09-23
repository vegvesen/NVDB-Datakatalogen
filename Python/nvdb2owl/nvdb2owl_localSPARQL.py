vot=174
kommune=3403


localPath = "C:\\DATA\\GitHub\\vegvesen\\NVDB-Datakatalogen\\Python\\nvdb2owl"
sqFileName=localPath + '\\data\\gdf.sparql'

#proxies = {}
proxies = {'http': 'http://proxy.vegvesen.no:8080'}

nvdbVoPath = "http://rdf.vegdata.no/nvdb/vegobjekt#"
nvdbVnPath = "http://rdf.vegdata.no/nvdb/vegnett#"
nvdbOTLPath = "http://rdf.vegdata.no/nvdb/nvdb-owl#"
gdfOTLPath = "http://rdf.gdf.org/gdf-owl#"
nvdb_otl_gh = 'https://raw.githubusercontent.com/vegvesen/NVDB-Datakatalogen/master/OWL/nvdb-owl.ttl'
gdf_otl_gh = 'https://raw.githubusercontent.com/jetgeo/GIS2OWL/master/GDF/gdf-owl.ttl'
lr_set_gh = 'https://raw.githubusercontent.com/jetgeo/GIS2OWL/master/LRS_NVDB_GDF.ttl'

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
               SELECT DISTINCT ?uri ?nvdb_id ?label
               WHERE {
                ?class rdfs:subClassOf+ nvdb:Vegobjekttype .
                ?class nvdb:nvdb_id """ + vot_id + """ .
                ?uri rdfs:domain ?class .
                ?uri nvdb:nvdb_id ?nvdb_id .
                ?uri rdfs:label ?label .
                }"""
    qres=otl.query(query)
    return qres

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
    qres=otl.query(query)
    return qres

def sqFile2Array(fn):
    #Leser SPARQL-queries fra fil til liste
    sqfile = open(sqFileName,'r',encoding='utf-8')
    Lines = sqfile.readlines()

    qList = [[]]
    qRow = []
    # Leser prefixer i headingen
    strPrefix = ''
    for line in Lines:
        if line.startswith('/'):
            break
        else:
            strPrefix += line
    qRow =['prefix',strPrefix]

    # Leser queries en og en
    curQ = ''
    qName=''
    qCount = 0
    for line in Lines:
        if line.startswith('/'):
            if qCount > 0:
                qRow= [qName,curQ]
            qList.append(qRow)
            qCount += 1
            #print('Query number ', qCount)
            curQ = ''
        elif line.startswith('#NAME'):
            qName = line[6:].replace("\n", " ")
            #print('Query name: ', qName)
        elif qCount > 0:
            curQ += line
    curQ.encode(encoding='utf-8',errors='strict')
    qRow = [qName, curQ]
    qList.append(qRow)
    del qList[0]
    return qList



# *********************************
# Her begynner selve moroa!
import sys, requests,datetime
if not [k for k in sys.path if localPath in k]:
    print('Føyer', localPath, 'til søkestien')
    sys.path.append(localPath)
from nvdbapiv3 import nvdbFagdata

startTime = datetime.datetime.now()

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
    # Leser ontologier
    print(str(datetime.datetime.now()) + ' Leser inn NVDB-OTL fra ', nvdb_otl_gh)
    otl_nvdb = Graph()
    otl_nvdb.parse(nvdb_otl_gh,format="turtle")
    print(str(datetime.datetime.now()) + ' Leser inn GDF-OTL fra ', gdf_otl_gh)
    otl_gdf = Graph()
    otl_gdf.parse(gdf_otl_gh,format="turtle")
    print(str(datetime.datetime.now()) + ' Leser inn linkset fra ', lr_set_gh)
    otl_lset = Graph()
    otl_lset.parse(lr_set_gh,format="turtle")
    #Slår sammen ontologier til en stor graf
    otl = Graph()
    otl = otl_nvdb + otl_gdf + otl_lset

    # Oppslag i NVDB-OTL (SPAQRL) etter uri og navn for objekttypen
    print(str(datetime.datetime.now()) + ' Oppslag i NVDB-OTL (SPAQRL) etter uri og navn for objekttypen')
    sqres=get_nvdb_ft(str(sokeobjekt.objektTypeDef['id']))

    # Henter ut sosinavn og uri fra resultatet
    for row in sqres:
        #print(str(datetime.datetime.now()) + ' URI ', row.uri ,': sosinavn ', row.sosinavn)
        sosinavn = row.sosinavn
        uri= row.uri
    sosinavn.encode(encoding='utf-8', errors='strict')

    classURI = URIRef(uri)
    # Endre objekttypenavn
    print(str(datetime.datetime.now()) + ' Setter lagnavn: ' + sosinavn + ' (' + str(uri) + ')')
    lagnavn = sosinavn

    # Slå opp egenskaps-uri-er og enum-uri-er i NVDB-OT (SPARQL)
    print(str(datetime.datetime.now()) + ' Oppslag i NVDB-OTL (SPARQL) på egenskaper')
    sqresEgenskaper = get_nvdb_pt(str(sokeobjekt.objektTypeDef['id']))
    print(str(datetime.datetime.now()) + ' Oppslag i NVDB-OTL (SPARQL) på tillatte verdier')
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
                    for ptRow in sqresEgenskaper:
                        if 200000 + int(ptRow.nvdb_id) == int(assosiasjonen['id']):
                            egenskapURI = ptRow.uri
                            g.add((objectURI, URIRef(egenskapURI), URIRef(nvdbVoPath + str(assosiasjonen['verdi']))))

            # Slå opp egenskaps-uri i NVDB-OT (SPARQL)
            egenskapURI = ''
            for ptRow in sqresEgenskaper:
                if int(ptRow.nvdb_id) == int(egenskapen['id']):
                    egenskapURI = ptRow.uri
                    #print(egenskapURI)
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
                                #print(enumUri)
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
            print(str(datetime.datetime.now()) + ' Prosessert ', count, 'av', sokeobjekt.antall, 'NVDB-objekter av objekttypen ', lagnavn)

        objektet = sokeobjekt.nesteForekomst()

    print(str(datetime.datetime.now()) + ' Prosessert ', count, 'av', sokeobjekt.antall, 'NVDB-objekter av objekttypen ', lagnavn)

    # Lister grafen
    #print(g.serialize(format="turtle").decode())
    # Skriver til fil (turtle)
    print(str(datetime.datetime.now()) + ' Skriver til NVDB-Turtle-fil')
    g.serialize(destination=localPath + "\\data\\" + str(kommune) + "_" + lagnavn + ".ttl", format="turtle")

    # Konvertering til GDF vha SPARQL

    #Lager graf med både OTL og individer
    gOTL = otl + g
    gdf_g = Graph()
    gdf_g.bind("nvdb_vo", nvdb_ns_vo)
    gdf_g.bind("gdf", gdfOTLPath)

    #Les queries fra fil, sekvensiell prosessering
    queryList = sqFile2Array(sqFileName)
    i = 0
    for queryRow in queryList:
        if i == 0:
            prefix=queryList[i][1]
        else:
            print('')
            qName = queryList[i][0]
            print(str(datetime.datetime.now()) + ' Konverteringsspørring : ', qName)
            query = prefix + '\n' + queryList[i][1]
            #print('Query: ', query)
            # Kjører spørring og lager ny graf som resultat
            gdf_res=gOTL.query(query)
            newg = Graph().parse(data=gdf_res.serialize(format='xml'))
            #print(newg.serialize(format="turtle").decode())
            gdf_g += newg

            cntGdf = 0
            for subject, predicate, object in newg:
                if not (subject, predicate, object) in newg:
                    raise Exception("Iterator / Container Protocols are Broken!!")
                cntGdf += 1
            if cntGdf > 0:
                print(str(datetime.datetime.now()) + ' Generert  ' + str(cntGdf) + ' tripler' )
                # Lister grafen
                # print(gdf_g.serialize(format="turtle").decode())
            else:
                print(str(datetime.datetime.now()) + ' Ingen matchende GDF features')
        i += 1

    gdf_gg = Graph()
    gdf_gg = gdf_g + otl_gdf
    #gdf_gg.remove((None, RDF.type, classURI))  # remove all triples refering to NVDB-type
    print('')
    print(str(datetime.datetime.now()) + ' Skriver til GDF-Turtle-fil')
    gdf_gg.serialize(destination=localPath + "\\data\\" + str(kommune) + "_gdf_" + lagnavn + ".ttl", format="turtle")

timePassed =datetime.datetime.now() - startTime


print(str(datetime.datetime.now()) + ' Ferdig! Tidsforbruk: ' + str(timePassed) + ')')
