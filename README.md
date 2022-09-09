# NVDB Datakatalogen

Repository for  tilgjengeliggjøring av NVDB Datakatalogen (https://datakatalogen.vegdata.no/) i alternative og standardiserte strukturer og teknologier. Tilretteleggingen er basert på modell-dreven arkitektur (MDA) i henhold til ISO 19103, ISO 19109, ISO 19136 og ISO 19150-2. 

Sammenhenger og prosesser er illustrert i [denne figuren](https://github.com/vegvesen/NVDB-Datakatalogen/blob/master/Wiki/NVDB%20Datakatalogen-Prosess.png).

## Innhold:

### [UML](https://github.com/vegvesen/NVDB-Datakatalogen/tree/master/UML)

UML-modell som gjenspeiler NVDB Datakatalogen direkte.

- [XMI-filer](https://github.com/vegvesen/NVDB-Datakatalogen/tree/master/UML/XMI) for original UML-representasjon av NVDB Datakatalogen.
- [PNG-rasterfiler](https://github.com/vegvesen/NVDB-Datakatalogen/tree/master/UML/PNG) for alle diagrammer i UML-modellen.

### [SOSI-UML](https://github.com/vegvesen/NVDB-Datakatalogen/tree/master/SOSI-UML)

UML-modell i henhold til modelleringsregler for SOSI. Avleda av NVDB-UML-modellen. Modellen finnes også i SOSI-modellregister under "Andre viktige komponenter" 

- [XMI-filer](https://github.com/vegvesen/NVDB-Datakatalogen/tree/master/SOSI-UML) for den SOSI-tilpassede UML-modellen avledet av den originale UML-representasjonen.

### [GML](https://github.com/vegvesen/NVDB-Datakatalogen/tree/master/GML)
GML-Applikasjonsskjema for NVDB Datakatalogen, avleda fra SOSI-UML-modellen.

- Applikasjonsskjema for [komplett NVDB Datakatalog](https://github.com/vegvesen/NVDB-Datakatalogen/tree/master/GML).
- Tilpassa applikasjonsskjema for [produktspesifikasjoner](https://github.com/vegvesen/NVDB-Datakatalogen/tree/master/GML/PS).

### [OWL](https://github.com/vegvesen/NVDB-Datakatalogen/tree/master/OWL)
OWL-Ontologi for NVDB Datakatalogen, avleda fra SOSI-UML-modellen.

- [Komplett ontologi](https://github.com/vegvesen/NVDB-Datakatalogen/tree/master/OWL/core) for NVDB Datakatalogen.
- [Kategorisering](https://github.com/vegvesen/NVDB-Datakatalogen/tree/master/OWL/category) av vegobjekttyper.
- [Linking Rules Sets](https://github.com/vegvesen/NVDB-Datakatalogen/tree/master/OWL/lrs) for kobling til andre ontologier.
- IFC [PropertySetDefinitions for NVDB](https://github.com/vegvesen/NVDB-Datakatalogen/tree/master/OWL/ifc) som OWL-Ontologi .

### [IFC-PSD](https://github.com/vegvesen/NVDB-Datakatalogen/tree/master/IFC-PSD)

IFC PropertySetDefinitions i XML-format, i henhold til buildingSMART sitt XML-skjema.

------

### Andre mapper:

#### [Script](https://github.com/vegvesen/NVDB-Datakatalogen/tree/master/Script)
Enterprise Architect-script for transformasjon mellom modellrepresentasjoner.

#### [SC](https://github.com/vegvesen/NVDB-Datakatalogen/tree/master/SC)
Konfigureringsfiler for ShapeChange.
