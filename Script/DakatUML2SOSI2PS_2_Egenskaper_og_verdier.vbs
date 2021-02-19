'option explicit

!INC Local Scripts.EAConstants-VBScript
!INC NVDB._felles
!INC NVDB._parametre

' Script Name: DakatUML2SOSI2PS_2_Egenskaper_og_verdier
' Author: Knut Jetlund
' Purpose: Tilpasser innhold i produktspesifikasjoner ut i fra koblingstabeller mot vegobjekttypekategori
' Date: 20210212
'

const votkatId = "302,303"

sub main

	'Vise og tøm scriptvinduer
	outputTabs
	'Kobler til modell og database
	connect2models
	'Henter tabell for vegobjekttypekategorier
	set rsVOTKategorier = CreateObject("ADODB.Recordset")
	rsVOTKategorier.Open "SELECT * FROM VEGOB_TYPE_KAT", dbDakat, 3, 1
	'Lager koblingstabell for vegobjekttyper og vegobjekttypekategorier	
	set rsVTKat = CreateObject("ADODB.Recordset")
	rsVTKat.Open "SELECT * FROM KOPL_VOT_KAT", dbDakat, 3, 1
	'Lager koblingstabell for egenskapstyper og vegobjekttypekategorier	
	set rsETKat = CreateObject("ADODB.Recordset")
	rsETKat.Open "SELECT * FROM KOPL_ET_KAT", dbDakat, 3, 1
	'Lager koblingstabell for kodelisteverdier og vegobjekttypekategorier	
	set rsTVKat = CreateObject("ADODB.Recordset")
	rsTVKat.Open "SELECT * FROM KOPL_TV_KAT", dbDakat, 3, 1

	'Hent valgt hovedpakke
	dim thePackage as EA.Package
	set thePackage = Repository.GetTreeSelectedPackage()
	Repository.WriteOutput "Script", Now & " Hovedpakke: " & thePackage.Name & " (" & thePackage.PackageGUID & ")", 0 

	dim katPackage as EA.Package
	for each katPackage in thePackage.Packages
		Repository.WriteOutput "Script", Now & " Pakke for kategori: " & katPackage.Name & " (" & katPackage.Alias & ")", 0 
		'Filtrer koblingstabeller
		rsETKat.Filter = "ID_VOBJ_TYP_KAT = " & katPackage.Alias
		rsTVKat.Filter = "ID_VOBJ_TYP_KAT = " & katPackage.Alias
				
		for each pkOT in katPackage.Packages
			Repository.WriteOutput "Script", Now & " Pakke: " & pkOT.Name & " (" & pkOT.Alias & ")", 0 
			for idxE = 0 to pkOT.Elements.Count -1 
				set element = pkOT.Elements.GetAt(idxE)
				If UCase(element.Stereotype)="FEATURETYPE" then
					'Featuretype
					Repository.WriteOutput "Script", Now & " Vegobjekttype: " & element.Name & " (" & element.Alias & ")", 0 
					'Sjekk om hver enkelt attributt skal være med, og sett multiplisitet ut fra viktighet
					For idxA = 0 to element.Attributes.Count - 1
						Set eAttributt = element.Attributes.GetAt(idxA)
						if eAttributt.Alias <> "" then
							rsETKat.MoveFirst()
							rsETKat.Find("ID_EGENSKAPSTYPE=" & eAttributt.Alias)
							'Sjekk om den inngår i koblingsliste
							if not rsETKat.EOF then
								Repository.WriteOutput "Script", Now & " Egenskap oppdateres: " & eAttributt.Name & " (" & eAttributt.Alias & ") inngår i kategorien", 0 
								set aTag = eAttributt.TaggedValues.GetByName("Viktighet")
								If not aTag is nothing then
									if aTag.Value = "Påkrevd ved nyregistrering" then 
										'Obligatorisk attributt dersom viktighet = "Påkrevd ved nyregistrering".
										Repository.WriteOutput "Script", Now & " Egenskapen " & eAttributt.Name & " (" & eAttributt.Alias & ") har viktighet " & aTag.Value, 0 
										eAttributt.LowerBound = 1
										eAttributt.Update
									end if
								end if		
							else
								Repository.WriteOutput "Script", Now & " Egenskap slettes: " & eAttributt.Name & " (" & eAttributt.Alias & ") inngår IKKE i kategorien", 0 
								'Nei-->Slett attributten 
								element.Attributes.DeleteAt idxA, False
							end if
						end if	
					next
					element.Attributes.Refresh
				else
					'Codelist
					if element.Alias <> "" then
						'Sjekk om kodelisten skal være med (kodeliste-alias, som er likt tilhørende attributt, inngår i rsETKat)
						rsETKat.MoveFirst()
						rsETKat.Find("ID_EGENSKAPSTYPE=" & element.Alias)
						if not rsETKat.EOF then
							Repository.WriteOutput "Script", Now & " Kodeliste oppdateres: " & element.Name & " (" & element.Alias & ") inngår i kategorien", 0 
							'For hver kodelisteverdi: Sjekk om den inngår i koblingsliste
							For idxA = 0 to element.Attributes.Count - 1
								Set eAttributt = element.Attributes.GetAt(idxA)
								if eAttributt.Alias <> "" then
									rsTVKat.MoveFirst()
									rsTVKat.Find("ID_TILLATT_VERDI=" & eAttributt.Alias)
									'Sjekk om den inngår i koblingsliste
									if not rsTVKat.EOF then
										Repository.WriteOutput "Script", Now & " Kodelisteverdi oppdateres: " & eAttributt.Name & " (" & eAttributt.Alias & ") inngår i kategorien", 0 
										set aTag = eAttributt.TaggedValues.GetByName("Viktighet")
									else
										'Nei-->Slett attributten 
										Repository.WriteOutput "Script", Now & " Kodelisteverdi slettes: " & eAttributt.Name & " (" & eAttributt.Alias & ") inngår IKKE i kategorien", 0 
										element.Attributes.DeleteAt idxA, False
									end if
								end if	
							next
							element.Attributes.Refresh
						else
							Repository.WriteOutput "Script", Now & " Kodeliste slettes: " & element.Name & " (" & element.Alias & ") inngår IKKE i kategorien", 0 
							'Nei-->Slett kodeliste 
							pkOT.Elements.DeleteAt idxE, False
						end if
					
					end if
				end if	
			next
			pkOT.elements.Refresh
		
			'Mulighet for å hoppe ut av løkka - fjernes når scriptet er ferdig.
			'dim msgAnsw
			'msgAnsw = MsgBox("Sjekk modellen nå", vbOkCancel, "OWL")
			'if msgAnsw = 2 then
			'	Repository.WriteOutput "Script", Now & " Ferdig, sjekk resultatfilene...", 0 
			'	exit sub
			'end if	
		next
	next

	Repository.WriteOutput "Script", Now & " Ferdig, sjekk resultatfilene...", 0 
		

end sub

main()