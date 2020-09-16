# Python code to
# demonstrate readlines()
import array

sqFileName='C:\\DATA\\GitHub\\vegvesen\\NVDB-Datakatalogen\\Python\\nvdb2owl\\data\\gdf.sparql'

def sqFile2Array(fn):
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
            print('Query number ', qCount)
            curQ = ''
        elif line.startswith('#NAME'):
            qName = line[6:].replace("\n", " ")
            print('Query name: ', qName)
        elif qCount > 0:
            curQ += line

    qRow = [qName, curQ]
    qList.append(qRow)
    del qList[0]
    return qList

#for q in qNList:
#    print('Row: ', q, '\n' )
#for qRow in qList:
#    print(qList[0][1])
#    for item in qRow:
#        print('Item: ', item )

queryList = sqFile2Array(sqFileName)
i=0
for queryRow in queryList:
    print('')
    print('Query name: ', queryList[i][0])
    print('Query: ', queryList[i][1])
    i+=1

a = [u"✓ means check", "LineÃ¦rPosisjon"]
print(a)
print(u", ".join(a))
