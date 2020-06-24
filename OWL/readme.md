# OWL-Ontologi for NVDB Datakatalogen

OWL-Ontologi i Turtle-format, generert fra SOSI-UML-modell for NVDB Datakatalogen. 

## Hovedstruktur for klasser:
- Rotobjekt for NVDB
  - Kodeliste: Rotobjekt for kodelister. 
    - Alle kodelister er definert som egne klasser og gruppert på vegobjekttyper under denne klassen.
  - Vegobjekttype: Rotobjekt for vegobjekttyper. 
    - Alle vegobjekttyper ligger direkte under denne klassen
    - Klassen Vegobjekttype er definert som subklasse av GeoSPARQL.Feature og ISO 19109.AnyFeature
- Stedfesting: Rotobjekt for stedfestingskonsepter
  - Geometri: Konsepter for stedfesting, med linker til GeoSparql og ISO 19107-ontologien.
  - Lineær posisjon: Konsepter for linere referanser, med linker til ISO 19148-ontologi fra INTERLINK, ettersom offisiell ISO 19148-ontologi ikke finnes foreløpig. 

Alle klasser har angitt tilleggsinformasjon med offisiell NVDB-ID, definisjon, NVDB-navn og SOSI-navn. 

## Hovedstruktur for properties:
-Object properties pr vegobjekttype: Rot for object properties. 
  - Alle properties som peker til en kodeliste eller en annen klasse (assosiasjon fra NVDB) er gruppert pr vegobjekttype under denne klassen. 
  - Properties er tildelt sin vegojekttype som domain og tilhørende kodeliste eller vegobjekttype som range. 
  - Object Properties har angitt tillegsinformasjon med offisiell NVDB-ID, definisjon, NVDB-navn og SOSI-navn.  
  - Alle assosiasjoner er satt som inverse av tilsvarende assosiasjon i motsatt retning. 
- Data properties pr vegobjekttype: Rot for data properties. 
  - Alle propertes med en enkel verdi er gruppert pr vegobjekttype under denne klassen. 
  - Properties er tildelt sin vegojekttype som domain og tilhørende xsd-datatype som range. 
  - Data Properties har angitt tilleggsinformasjon med offisiell NVDB-ID, definisjon, NVDB-navn og SOSI-navn.  
- Stedfesting av vegobjekter: Rot for properties som peker til en av stedfestingsklassene.

## Individer:
 - Kodelisteverdier er definert som individer av sin kodeliste
 - Alle kodelisteverdier har angitt tilleggsinformasjon med offisiell NVDB-ID, definisjon, NVDB-navn og SOSI-navn.  
  
