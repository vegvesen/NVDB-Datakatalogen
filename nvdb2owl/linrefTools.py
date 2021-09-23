import time
from datetime import datetime
import logging
import requests
import shapely.wkt
from shapely.ops import linemerge, LineString, Point
from functools import reduce
from functools import lru_cache
import re
from ratelimit import limits
import ratelimit
import backoff

#API = 'https://pm1.utv.vegvesen.no/nvdb/api/v3/'
API = 'https://www.vegvesen.no/nvdb/api/v3/'
#API = 'https://www.utv.vegvesen.no/nvdb/api/v3/'
#API = 'https://nvdbw01.kantega.no/nvdb/api/v3/'
# API = 'https://apilesv3-stm.utv.atlas.vegvesen.no/'
# API = 'https://nvdbapiles-v3-stm.utv.atlas.vegvesen.no/'
#API = 'https://apilesv3.test.atlas.vegvesen.no/'

def linref2geom(sekvens_nr, fra, til, kommunenr, retning):
    url = API + "vegnett/veglenkesekvenser/" + str(sekvens_nr)
    json = fetchJson(url)
    lst = []
    fra = float(fra)
    til = float(til)
    for veglenke in json["veglenker"]:
        if 'sluttdato' in veglenke \
           or veglenke['detaljnivå'] == 'Vegtrase' \
           or int(veglenke['geometri']['kommune']) != int(kommunenr):
            continue
        start = float(veglenke['startposisjon'])
        slutt = float(veglenke['sluttposisjon'])
        lengde = float(veglenke['geometri']['lengde'])
        if within(start, slutt, fra, til):
            lst.append({
            'start': start,
            'slutt': slutt,
            'veglenkesekvens': sekvens_nr,
            'retning': retning.lower(),
            'geom': [geom(veglenke)]
            }) 
        elif overlaps(start, slutt, fra, til):
            cutGeo = cut(geom(veglenke), start, slutt, fra, til, lengde)
            if cutGeo:
                lst.append({
                'start': max(start, fra),
                'slutt': min(slutt, til),
                'veglenkesekvens': sekvens_nr,
                'retning': retning.lower(),
                'geom': [cutGeo]
                })

    lst = sorted(lst, key = lambda x: x['start'])
    if len(lst) > 1:
        lst = reduce(mergeRef, [[lst[0]]] + lst[1:])

    for obj in lst:
        geo = linemerge(obj['geom'])
        if geo.geom_type == 'MultiLineString':
            geo = fixMulti(geo)
        obj['geom'] = geo
    return lst


def linref2geomPunkt(sekvens_nr, posisjon):
    url = API + "vegnett/veglenkesekvenser/" + str(sekvens_nr)
    json = fetchJson(url)
    lst = []
    posisjon = float(posisjon)
    for veglenke in json["veglenker"]:
        if 'sluttdato' in veglenke \
           or veglenke['detaljnivå'] == 'Vegtrase':
            continue
        start = float(veglenke['startposisjon'])
        slutt = float(veglenke['sluttposisjon'])
        if withinPunkt(start, slutt, posisjon):
            geo = geomPunkt(veglenke, posisjon)
            lst.append({
                'posisjon': posisjon,
                'veglenkesekvens': sekvens_nr,
                'geom': geo
            })
    return lst

def fixMulti(geo):
    fst = list(geo[0].coords)
    lst = list(geo[-1].coords)
    if isCircular(fst):
        if geo.has_z:
            fst[0] = (fst[0][0] + 0.000001, fst[0][1], fst[0][2])
        else:
            fst[0] = (fst[0][0] + 0.000001, fst[0][1])
    if isCircular(lst):
        if geo.has_z:
            lst[-1] = (lst[-1][0] + 0.000001, lst[-1][1], lst[-1][2])
        else:
            lst[-1] = (lst[-1][0] + 0.000001, lst[-1][1])
    return linemerge([LineString(fst)] + [x for x in geo[1:-2]] + [LineString(lst)])

def log(tekst): 
    filename='log/' + todaysdate() + '.log'
    logging.basicConfig(filename=filename, level=logging.DEBUG)
    logging.info(tekst)

def todaysdate():
    return datetime.today().strftime("%Y%m%d")

def isCircular(line):
    return line[0] == line[-1]

def mergeRef(o1, o2):
    if o1[-1]['slutt'] == o2['start'] and o1[-1]['veglenkesekvens'] == o2['veglenkesekvens']:
        o1[-1]['slutt'] = o2['slutt']
        o1[-1]['geom'] = o1[-1]['geom'] + o2['geom']
    else:
        o1.append(o2)
    return o1

def super2geom(sekvens_nr, fra, til, kommunenr, retning, felt):
    url = API + "vegnett/veglenkesekvenser?superid=" + str(sekvens_nr)
    json = fetchJson(url)
    lst = []
    fra = float(fra)
    til = float(til)
    for sekv in json['objekter']:
        veglenkesekvensid = sekv['veglenkesekvensid']
        for veglenke in sekv["veglenker"]:
            if 'sluttdato' in veglenke \
               or (int(veglenke['geometri']['kommune']) != int(kommunenr)) \
               or (feltstr(felt) not in (feltstr(veglenke['superstedfesting'].get('kjørefelt') or []))):
                continue
            start = float(veglenke['superstedfesting']['startposisjon'])
            slutt = float(veglenke['superstedfesting']['sluttposisjon'])
            lengde = float(veglenke['lengde'])
            retning = veglenke['superstedfesting'].get('retning', 'MED')
            geo = geom(veglenke)
            if retning == 'MOT':
                geo.coords = geo.coords[::-1]
            if within(start, slutt, fra, til):
                lst.append({
                'start': veglenke['startposisjon'],
                'slutt': veglenke['sluttposisjon'],
                'veglenkesekvens': veglenkesekvensid,
                'retning': retning.lower(),
                'geom': [geo]
                }) 
            elif overlaps(start, slutt, fra, til):
                cutGeo = cut(geo, start, slutt, fra, til, lengde)
                if cutGeo:
                    lst.append({
                    'start': superstedfesting2veglenke(max(start, fra), start, slutt, \
                                                       float(veglenke['startposisjon']), float(veglenke['sluttposisjon'])),
                    'slutt': superstedfesting2veglenke(min(slutt, til), start, slutt, \
                                                       float(veglenke['startposisjon']), float(veglenke['sluttposisjon'])),
                    'veglenkesekvens': veglenkesekvensid,
                    'retning': retning.lower(),
                    'geom': [cutGeo]
                    })

    lst = sorted(lst, key = lambda x: (x['veglenkesekvens'], x['start']))
    if len(lst) > 1:
        lst = reduce(mergeRef, [[lst[0]]] + lst[1:])

    for obj in lst:
        geo = linemerge(obj['geom'])
        if geo.geom_type == 'MultiLineString':
            geo = fixMulti(geo)
        obj['geom'] = geo
    return lst

def super2geomPunkt(sekvens_nr, posisjon, felt):
    url = API + "vegnett/veglenkesekvenser?superid=" + str(sekvens_nr)
    json = fetchJson(url)
    lst = []
    posisjon = float(posisjon)
    for sekv in json['objekter']:
        veglenkesekvensid = sekv['veglenkesekvensid']
        for veglenke in sekv["veglenker"]:
            if 'sluttdato' in veglenke \
               or (feltstr(felt) and (feltstr(veglenke['superstedfesting'].get('kjørefelt') or []) != feltstr(felt))):
                continue
            start = float(veglenke['superstedfesting']['startposisjon'])
            slutt = float(veglenke['superstedfesting']['sluttposisjon'])
            if withinPunkt(start, slutt, posisjon):
                nyPos = superstedfesting2veglenke(posisjon, start, slutt, \
                                                  float(veglenke['startposisjon']), \
                                                  float(veglenke['sluttposisjon']))
                geo = geomPunkt(veglenke, nyPos)
                lst.append({
                'posisjon': nyPos,
                'veglenkesekvens': veglenkesekvensid,
                'geom': geo
                })
    return lst

def linref2all(sekvens_nr, fra, til, kommunenr, retning = 'med', felt = []):
    if not retning: retning = 'med' # fix for objekter sendt med retning None
    res = linref2geom(sekvens_nr, fra, til, kommunenr, retning) + super2geom(sekvens_nr, fra, til, kommunenr, retning, felt)
    if not res:
        print("sekv: %s, fra: %s, til: %s, kommunenr: %s, retning: %s, felt: %s\n" % (sekvens_nr, fra, til, kommunenr, retning, felt))
    return res

def linref2allPunkt(sekvens_nr, posisjon, felt = []):
    return linref2geomPunkt(sekvens_nr, posisjon) + super2geomPunkt(sekvens_nr, posisjon, felt)

def feltstr(feltlst):
    return "#".join(feltlst)

def superstedfesting2veglenke(stedf, s_start, s_slutt, v_start, v_slutt):
    scale = (s_slutt - s_start) / (v_slutt - v_start)
    return ((stedf - s_start) / scale) + v_start

session = requests.Session()
session.headers.update({'X-Client': 'Elveg 2.0'})
@lru_cache(maxsize=None)
def fetchJson(url, s = session):
    return fetchJsonHelper(url, s)

@backoff.on_exception(backoff.expo, ratelimit.exception.RateLimitException, max_time=60)
@limits(10, 1) # max 10 calls per 1 sec
def fetchJsonHelper(url, s):
    #print(url)
    for i in range(5):
        resp = s.get(url)
        if resp.status_code == 200:
            return resp.json()
        time.sleep(10 + i*30)
    raise ConnectionError(resp.status_code)

def overlaps(start, slutt, fra, til):
    return (fra >= start and fra < slutt) or (til > start and til <= slutt)

def within(start, slutt, fra, til):
    return start >= fra and slutt <= til

def withinPunkt(start, slutt, posisjon):
    return (start < posisjon and slutt >= posisjon) or (start == 0.0 and posisjon == 0.0)

def geom(veglenke):
    wkt = veglenke['geometri']['wkt']
    return wkt2line(wkt)

def reverseWKT(wkt):
    l = wkt2line(wkt)
    l.coords = l.coords[::-1]
    return l.wkt

def wkt2line(wkt):
    simpledec = re.compile(r"-?\d+\.\d+")
    wkt = re.sub(simpledec, mround, wkt)
    line = shapely.wkt.loads(wkt)
    #if hasMissingZ(wkt): # transform to NaN at later stage.
        #line = shapely.ops.transform(_to_2d, line)
    return line

def hasMissingZ(wkt):
    return re.search(r"-999999", wkt)

# https://github.com/Toblerity/Shapely/issues/709
def _to_2d(x, y, z):
    return tuple(filter(None, [x, y]))

def geomPunkt(veglenke, ref):
    line = geom(veglenke)
    nyRef = refFraSekvensTilVeglenke(veglenke, ref)
    punkt = line.interpolate(nyRef, normalized=True)
    return punkt

def refFraSekvensTilVeglenke(veglenke, ref):
    fra = float(veglenke['startposisjon'])
    til = float(veglenke['sluttposisjon'])
    diff = til - fra
    return (ref - fra) / diff

def mround(match):
    return "{:.2f}".format(float(match.group()))

def almostEqual(a, b, scale, tolerance = 0.001):
    return abs(a - b) <= (tolerance / scale)

def cut(line, vl_fra, vl_til, obj_fra, obj_til, lengde):
    vl_len = vl_til - vl_fra
    scale = lengde * vl_len
    if obj_fra <= vl_fra and obj_til >= vl_til:
        return line
    elif obj_fra <= vl_fra and obj_til < vl_til:
        distance = (obj_til - vl_fra) / vl_len
        coords = list(line.coords)
        for i, p in enumerate(coords):
            pd = line.project(Point(p), normalized=True)
            if almostEqual(pd, distance, scale):
                if i == 0:
                    return []
                else:
                    return LineString(coords[:i+1])
            if pd > distance:
                cp = line.interpolate(distance, normalized=True)
                if line.has_z:
                    return LineString(coords[:i] + [(cp.x, cp.y, (coords[i-1][2] + coords[i][2]) / 2)])
                else:
                    return LineString(coords[:i] + [(cp.x, cp.y)])
    elif obj_fra > vl_fra and obj_til >= vl_til:
        distance = 1 - ((vl_til - obj_fra) / vl_len)
        coords = list(line.coords)
        for i, p in enumerate(coords):
            pd = line.project(Point(p), normalized=True)
            if almostEqual(pd, distance, scale):
                if i == 0 or i == (len(coords) - 1):
                    log("geom: %s, vl_fra %s, vl_til %s, obj_fra %s, obj_til %s, lengde %s" % (line, vl_fra, vl_til, obj_fra, obj_til, lengde))
                    return [] # single point line
                else:
                    return LineString(coords[i:])
            if pd > distance:
                cp = line.interpolate(distance, normalized=True)
                if line.has_z:
                    return LineString([(cp.x, cp.y, (coords[i-1][2] + coords[i][2]) / 2)] + coords[i:])
                else:
                    return LineString([(cp.x, cp.y)] + coords[i:])
    elif obj_fra > vl_fra and obj_til < vl_til:
        dist1 = 1 - ((vl_til - obj_fra) / vl_len)
        dist2 = (obj_til - vl_fra) / vl_len
        coords = list(line.coords)
        start = None
        for i, p in enumerate(coords):
            #print("i: %s\n" % i)
            pd = line.project(Point(p), normalized=True)
            #print("pd: %s dist1: %s, scale: %s, obj_fra: %s, obj_til: %s, vl_fra: %s, vl_til: %s" % (pd, dist1, scale, obj_fra, obj_til, vl_fra, vl_til))
            if start == None:
                #print("pd: %s dist1: %s, scale: %s" % (pd, dist1, scale))
                if almostEqual(pd, dist1, scale):
                    start = i
                    startP = []
                elif pd > dist1:
                    cp = line.interpolate(dist1, normalized=True)
                    start = i+1
                    if line.has_z:
                        startP = [(cp.x, cp.y, (coords[i-1][2] + coords[i][2]) / 2)]
                    else:
                        startP = [(cp.x, cp.y)]
            if almostEqual(pd, dist2, scale) and ((start - i) > 1):
                #print("pd: %s, dist2: %s, scale: %s, startP: %s, start: %s, i: %s, coords: %s" % (pd, dist2, scale, startP, start, i, coords))
                return LineString(startP + coords[start:i+1])
            elif pd > dist2:
                cp = line.interpolate(dist2, normalized=True)
                if i == 0 or i == (len(coords) - 1):
                    log("geom: %s, vl_fra %s, vl_til %s, obj_fra %s, obj_til %s, lengde %s" % (line, vl_fra, vl_til, obj_fra, obj_til, lengde))
                    return [] # single point line
                else:
                    if line.has_z:
                        return LineString(startP + coords[start:i] + [(cp.x, cp.y, (coords[i-1][2] + coords[i][2]) / 2)])
                    else:
                        return LineString(startP + coords[start:i] + [(cp.x, cp.y)])

def snuFeltListe(lst):
    res = []
    for felt in lst:
        n = int(felt[0])
        if n % 2: #odd
            n += 1
        else: # even
            n -= 1
        res.append(str(n) + felt[1:])
    return res

def isVegtrase(veglenkeid, ref):
    url = API + "vegnett/veglenkesekvenser/" + str(veglenkeid)
    json = fetchJson(url)
    for veglenke in json["veglenker"]:
        if 'sluttdato' in veglenke \
           or float(ref) < float(veglenke['startposisjon']) \
           or float(ref) > float(veglenke['sluttposisjon']):
            continue
        return veglenke['detaljnivå'] == 'Vegtrase'

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
    f = re.sub("app:", "", f)
    f = re.sub(":app", "", f)
    # f = re.sub("EPSG:6173", "http://www.opengis.net/def/crs/epsg/0/6173", f)
    f = re.sub("EPSG:5973", "http://www.opengis.net/def/crs/epsg/0/5973", f)
    # f = re.sub("http://www.opengis.net/def/crs/epsg/0/6173", "http://www.opengis.net/def/crs/epsg/0/5973", f)
    f = re.sub("-999999(\.0)?", "NaN", f)
    with open(file_location, 'w') as gml:
        gml.write(f)

def postProcessSOSI(file_location):
    with open(file_location, 'r') as sosi:
        f = sosi.read()
    f = re.sub("\.\.PRODUSENT \"Elveg 2.0\"", "..OBJEKTKATALOG Elveg 2.0", f)
    f = re.sub("(\.\.SOSI-NIV.+ )4", "\g<1>2", f)
    f = re.sub("(\.\.\.KOORDSYS )99", "\g<1>23", f)
    f = re.sub("(\d+ \d+) 250000", "\g<1>",  f)
    # f = re.sub("(\d+ \d+ )250000", "\g<1>-999999",  f)
    f = re.sub("^(\.\.\.LRFRAPOSISJON \d\.\d{1,8}).+", "\g<1>", f)
    f = re.sub("^(\.\.\.LRTILPOSISJON \d\.\d{1,8}).+", "\g<1>", f)
    with open(file_location, 'w') as sosi:
        sosi.write(f)

def postProcessAllFiles():
    import glob
    for f in glob.glob('/c/DATA/GIT/SOSI-Vegnett/GML/kommune/*.gml'): postProcessGML(f)
    for f in glob.glob('/c/DATA/GIT/SOSI-Vegnett/GML/kommune/**/*.gml'): postProcessGML(f)
    for f in glob.glob('/c/DATA/GIT/SOSI-Vegnett/GML/kommune/*.SOS'): postProcessSOSI(f)
    for f in glob.glob('/c/DATA/GIT/SOSI-Vegnett/GML/kommune/**/*.SOS'): postProcessSOSI(f)

def postProcessKommune(nr):
    import glob
    postProcessGML('/c/DATA/GIT/SOSI-Vegnett/GML/kommune/{}.gml'.format(nr))
    for f in glob.glob('/c/DATA/GIT/SOSI-Vegnett/GML/kommune/{}/*.gml'.format(nr)): postProcessGML(f)
    postProcessSOSI('/c/DATA/GIT/SOSI-Vegnett/GML/kommune/{}.SOS'.format(nr))
    for f in glob.glob('/c/DATA/GIT/SOSI-Vegnett/GML/kommune/{}/*.SOS'.format(nr)): postProcessSOSI(f)

def test():
    print("running tests")
    assert(snuFeltListe(['1','2']) == ['2','1'])
    assert(snuFeltListe(['1h1','2v1']) == ['2h1','1v1'])
    assert(overlaps(0.06979609, 0.61288609, 0.4018847, 0.5443459))
    print("tests pass")

if __name__ == '__main__':
    test()
    #linref2geom(705275, 0.0, 0.16063818)
    #super2geom(705275, 0.0, 0.16063818)
    #linref2all(1002615, 0.0, 0.0022977, 'MOT')
    #linref2all(705274, 0.88317984, 0.92373566)
