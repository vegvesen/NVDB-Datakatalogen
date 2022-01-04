'Datakatalogversjon
const FC_version = "2.27"
const FC_db = "C:\DATA\GitHub\vegvesen\NVDB-Datakatalogen\Access\NVDB_Datakatalogen_V227.mdb"
const strTargetNamespace = "https://raw.githubusercontent.com/vegvesen/NVDB-Datakatalogen/master/GML"

const svnSOSINVDBPath = "C:\DATA\Subversion\SOSI Modell\Andre viktige komponenter\NVDB\NVDB Datakatalogen versjon "
const strSOSIVersjon = "4.5"

const scPath = "C:\DATA\GitHub\vegvesen\NVDB-Datakatalogen\SC"
const sosiPath = "C:\DATA\GitHub\vegvesen\NVDB-Datakatalogen\SOSI-UML"
const gmlPath = "C:\DATA\GitHub\vegvesen\NVDB-Datakatalogen\GML"
const owlPath = "C:\DATA\GitHub\vegvesen\NVDB-Datakatalogen\OWL\"

const owlURI = "https://ontologi.atlas.vegvesen.no/nvdb/core/nvdb-owl"  '"http://rdf.vegdata.no/nvdb/nvdb-owl"

const csvPath = "C:\DATA\GitHub\vegvesen\NVDB-Datakatalogen\CSV"

const scProject = "SC_NVDB.eap"
const scTemplate = "SC_Core.eap"

'GUID-er for pakker mm
const guidNVDBVegobjekttyper = "{393D4B7A-A14F-4466-B0AF-06C59CB157F8}" 'Pakken Vegobjekttyper i original Datakatalog-UML
const guidSOSIDatakatalog = "{E7F57FAF-DB3F-4129-BB30-C903F137F599}" 'Pakken NVDB Datakatalog i SOSI-modellregister
const guidAbstrakteKlasser = "{B758BAF9-4870-4811-9AEB-28366B6CAB4D}" 'Pakken _AbstrakteKlasser i NVDB Datakatalog-hovedpakken i SOSI-modellregister

' GUID for SOSI-datatyper
const guidCharacterString = "{453EB6B1-D543-4f3d-BC53-E79283F6736C}"
const guidInteger = "{992C4B6C-785C-48a4-81A2-5F957E9C8A6B}"
const guidReal = "{281080FD-4373-4bf1-8F9E-606805BF9A0D}"
const guidDate = "{6B9D362B-ECF1-4605-800F-67219652B71E}"
const guidBoolean = "{B037C92D-03AE-4421-A554-7FDA5A49C381}"
const guidPunkt = "{BE6CCEB8-342A-4a44-BD46-8E5CBFDA9A91}"
const guidKurve = "{0708BC74-CF46-4cfe-93BE-878EC504768D}"
const guidFlate = "{46B26A69-F04C-4d11-B363-F3490340F5B7}"
const guidLRStrekning = "{3F3753C2-8665-4de7-AF70-4E8E833CE75D}"
const guidLRPunkt = "{4322CE4D-5CD6-4f58-949B-BF82F712762F}"


'***************************************************************************

'Parametre for konvertering til SOSI - stort sett utgått pga nye script.

const txtSOSIpakke = "NVDB Dokumentasjon"
const txtShortName = ""
const strPakker = "NVDB Dokumentasjon"
'Eksempler på pakkestrenger:
'"Vegreferanse" '"Antenne;Armeringsnett" '"Alle"
'Pakker i GLA: Belysningspunkt og Kabel + assosierte
const blnFellesegenskaper = False                                        'Arv fra SOSI Fellesegenskaper. Brukes i produktspesifikasjoner, ikke i konseptuel modell
const blnOLFV = False                                                           'Ta med kun egenskaper som er med i Objektliste ferdigvegsdata
const blnAssosierte = True                                                'Inkluder assosierte objekttyper i samme pakke
const blnSensitivitet = False                                             'Utelat sensitive egenskaper
const blnLRAttr = True                                                          'Angir om det skal legges til LR-attributter
const blnRemoveConstraints = True                                  'Angir om constraints skal fjernes
'Regler for konvertering av viktighet til multiplisitet
const blnPkrvd = True                                                           '"Påkrevd i database" medfører påkrevd i modellen
const blnPkrvdNyreg = False                                               '"Påkrevd ved nyregistrering" medfører påkrevd i modellen
const blnBetinget = False                                                 '"Betinget" medfører påkrevd i modellen
const blnAsDictionary = False                                            'Angir om kodelister skal være i GML-skjemafilene eller eksternt
const blnIndividualAS = True                                             'Angir om det skal genereres separate xsd-filer for hver pakke

'Arbeidsområde
const strMainPath = "C:\DATA\tmp"

'Pakke- og modellnavn til bruk i konverteringer
const strModelName = "NVDB Datakatalogen"
const strObjektPakke = "Vegobjekttyper"
const strDatatypePakke = "Datatyper"
const strNVDBSOSIPakke = "SOSI-Modeller"
const strSOSIFelles = "SOSI Fellesegenskaper"

const strSOSIModell = "SOSI Modell"
const strSOSIGK = "SOSI Generelle konsepter"
const strSOSIGO = "SOSI Generell objektkatalog"

