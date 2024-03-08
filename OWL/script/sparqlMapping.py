# Funksjoner for mapping i RDF vha SPARQL

#Importerer biblioteker
import sys, datetime
from rdflib import Graph
#from constants import *

def sqFile2Array(fn):
    #Leser SPARQL-queries fra fil til liste
    sqfile = open(fn,'r',encoding='utf-8')
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

def sqFileProcess(fn,oGraph,replaceText="[rt]",replaceWith="?rt"):
    #Sekvensiell prosessering av queries fra fil
    #Les queries fra fil, sekvensiell prosessering
    print(str(datetime.datetime.now()) + ' Fil med konverteringsspørringer : ', fn)
    queryList = sqFile2Array(fn)
    i = 0
    res_g=Graph()
    for queryRow in queryList:
        if i == 0:
            prefix=queryList[i][1]
        else:
            print('')
            qName = queryList[i][0]
            print(str(datetime.datetime.now()) + ' Konverteringsspørring : ', qName)
            query = prefix + '\n' + queryList[i][1]
            #Tilpasser query til input fra script
            queryStartTime = datetime.datetime.now()
            query=query.replace(replaceText,replaceWith)
            print(query)
            # Kjører spørring og lager ny graf som resultat

            q_res=oGraph.query(query)
            #for r in q_res:
            #    print(r)
            newg = Graph().parse(data=q_res.serialize(format='turtle'))
            print(str(datetime.datetime.now()) + ' Antall genererte tripler: ',len(newg))
            res_g += newg
            # cntRes = 0
            # for subject, predicate, object in newg:
            #     if not (subject, predicate, object) in newg:
            #         raise Exception("Iterator / Container Protocols are Broken!!")
            #     cntRes += 1
            # if cntRes > 0:
            #     print(str(datetime.datetime.now()) + ' Generert  ' + str(cntRes) + ' tripler' )
            # else:
            #     print(str(datetime.datetime.now()) + ' Ingen matchende tripler')
            queryTimePassed = datetime.datetime.now() - queryStartTime
            print(str(datetime.datetime.now()) + ' Tidsforbruk for spørring: ' + str(queryTimePassed) + ')')

        i += 1
    return res_g
