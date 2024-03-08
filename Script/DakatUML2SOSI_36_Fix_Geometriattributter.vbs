option explicit

!INC Local Scripts.EAConstants-VBScript
									   
!INC NVDB._felles
!INC NVDB._parametre
								 

' Script Name: DakatUML2SOSI_36_Fix_Geometriattributter
' Author: Knut Jetlund
' Purpose: Fikser geometriattributter: Fjerner doble
' Date: 2020-06-61


function fixGeometricAttributes()
	Repository.EnsureOutputVisible "Script"
	Repository.ClearOutput "Script"
	Repository.CreateOutputTab "Error"
	Repository.ClearOutput "Error"
	
	'Hardkoda liste over reserverte attributtnavn som må få suffix dersom de finnes i NVDB
	dim lstReservedAttrNames
	Set lstReservedAttrNames = CreateObject("System.Collections.ArrayList")
	lstReservedAttrNames.Add "kvalitet"
	lstReservedAttrNames.Add "målemetode" 
	lstReservedAttrNames.Add "høydereferanse"

	'Hardkoda liste over reserverte datatypenavn som må få prefix dersom de finnes i NVDB
	dim lstReservedDTNames
	Set lstReservedDTNames = CreateObject("System.Collections.ArrayList")
	lstReservedDTNames.Add "Kvalitet"
	lstReservedDTNames.Add "Målemetode"
	lstReservedDTNames.Add "Høydereferanse"

	' Get the currently selected package in the tree to work on
	set pkSOSINVDB = Repository.GetPackageByGuid(guidSOSIDatakatalog)		
	Repository.WriteOutput "Script", Now & " Hovedpakke: " & pkSOSINVDB.Name & " (" & pkSOSINVDB.PackageGUID & ")", 0 
	for each pkOT in pkSOSINVDB.Packages	
		if pkOT.PackageGUID <> guidAbstrakteKlasser then 
			Repository.WriteOutput "Script", Now & " ------------------------------------------------------------------------------", 0 
			Repository.WriteOutput "Script", Now & " Opprydding i pakken " & pkOT.Name, 0 
			for each element in pkOT.Elements
				if Ucase(element.Stereotype) = "FEATURETYPE" then
					Repository.WriteOutput "Script", Now & " Klasse: " & element.Name, 0 
					'Sjekker om geometriattributt finnes 
					dim lineAttrCount, pointAttrCount
					lineAttrCount = 0
					pointAttrCount = 0
					idxD = -1
					for idxA = 0 to element.Attributes.Count - 1
						'Sjekker om det finnes multiple geometriattributter og identifiserer de uten alias (lagt til i konverteringen)
						set eAttributt = element.Attributes.GetAt(idxA)
						if eAttributt.Name = "senterlinje" then
							lineAttrCount = lineAttrCount + 1
							'Identifiserer siste linjeattributt uten alias
							if eAttributt.Alias = "" then idxD = idxA
							Repository.WriteOutput "Script", Now & " Linjeattributt nr " & lineAttrCount & ": " & eAttributt.Name & "(" & eAttributt.Alias & ")", 0 
						elseif eAttributt.Name = "posisjon" then
							pointAttrCount = pointAttrCount + 1
							
							'Spesielt for punktposisjonene for Referansestrekning
							if element.Alias = "808" then
								select case eAttributt.Alias 
									case "9241" 
										eAttributt.Name = "posisjon1"
									case "9243" 
										eAttributt.Name = "posisjon2"
								end select
							end if	
														
							'Identifiserer siste punktattributt uten alias
							if eAttributt.Alias = "" then idxD = idxA
							Repository.WriteOutput "Script", Now & " Punktattributt nr " & pointAttrCount & ": " & eAttributt.Name & "(" & eAttributt.Alias & ")", 0 
						end if
						
						'Spesielt for gågateattributter
						if element.Alias = 813 then
							select case eAttributt.Alias
								case "9314"
									eAttributt.Name = "varetransportHverdagULørdagPeriode1FraKl"
								case "9315"
									eAttributt.Name = "varetransportHverdagULørdagPeriode1TilKl"
								case "9316"
									eAttributt.Name = "varetransportHverdagULørdagPeriode2FraKl"
								case "9317"
									eAttributt.Name = "varetransportHverdagULørdagPeriode2TilKl"
							end select
						end if
						
						'Attributtnavn som er reserverte for SOSI
						if lstReservedAttrNames.Contains(eAttributt.Name) then
							Repository.WriteOutput "Script", Now & " Attributt med navn reservert for SOSI, legger til suffix: " & eAttributt.Name, 0 			
							eAttributt.Name = eAttributt.Name & element.Name
							Repository.WriteOutput "Script", Now & " Nytt navn: " & eAttributt.Name, 0 									
						end if
						
						'Attributtnavn som starter med et tall (Ulovlig NCName)
						if IsNumeric(left(eAttributt.Name,1)) then
							Repository.WriteOutput "Script", Now & " Attributtnavn starter med tall, legger til prefix: " & eAttributt.Name, 0 			
							eAttributt.Name = "a" & eAttributt.Name
							Repository.WriteOutput "Script", Now & " Nytt navn: " & eAttributt.Name, 0 														
						end if 
						
						eAttributt.Update			
						
					next
					If lineAttrCount = 0 and pointAttrCount = 0 then
						Repository.WriteOutput "Error", Now & " Klassen mangler geometriattributter: " & element.Name, 0 	
					elseif lineAttrCount > 1 or pointAttrCount > 1 then
						Repository.WriteOutput "Error", Now & " Klassen har multiple geometriattributter: " & element.Name, 0 			
						if idxD <> -1 then
							set eAttributt = element.Attributes.GetAt(idxD)
							Repository.WriteOutput "Script", Now & " Sletter ekstra geometriattributt: " & eAttributt.Name & "(" & eAttributt.Alias & ")", 0 			
							element.Attributes.DeleteAt idxD, false
							element.Attributes.Refresh
						else
							Repository.WriteOutput "Error", Now & " Ekstra geometriattributt ikke identifisert", 0 			
						end if	
					end if
					
				'Kodelister som har navn som er reservert for SOSI	
				elseif lstReservedDTNames.Contains(element.Name) then
					Repository.WriteOutput "Script", Now & " Datatype med navn reservert for SOSI, legger til prefix: " & element.Name, 0 			
					dim ftEl as EA.Element
					for each ftEl in pkOT.Elements
						if Ucase(ftEl.Stereotype) = "FEATURETYPE" then
							element.Name = ftEl.Name & element.Name
							element.Update
							Repository.WriteOutput "Script", Now & " Nytt navn: " & element.Name, 0 			
						end if	
					next

				'Kodelistenavn som starter med et tall (Ulovlig NCName)
				elseif IsNumeric(left(element.Name,1)) then
					Repository.WriteOutput "Script", Now & " Datatypenavn starter med tall, legger til prefix: " & element.Name, 0 			
					element.Name = "TV" & element.Name
					element.Update
					Repository.WriteOutput "Script", Now & " Nytt navn: " & element.Name, 0 														
				end if	
			next
		end if
	next

	Repository.WriteOutput "Script", Now & " Ferdig, sjekk logg", 0 
	Repository.EnsureOutputVisible "Script"
end function

