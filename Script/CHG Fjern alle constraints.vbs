option explicit

!INC Local Scripts.EAConstants-VBScript

' Script Name: Fjern alle constraints
' Author: Knut Jetlund
' Purpose: Fjerner alle constraints i en modell
' Date: 20160915
'
' NOTE: Requires a package to be selected in the Project Browser
' 

'Recursive loop through subpackages, and do the thing
sub recPros(p)
	Repository.WriteOutput "Script", Now & " Package: " & p.Name, 0
	dim el as EA.Element
	for each el In p.elements
		if el.Stereotype="featureType" then
			dim idxT 
			dim cnstr As EA.Constraint
			Repository.WriteOutput "Script", Now & " Fjerner constraints for objekttype " & el.Name,0
            for idxT = 0 To el.Constraints.Count - 1
                el.Constraints.DeleteAt idxT, False
            next 
            el.Constraints.Refresh()
		end if
	next
	
	dim subP as EA.Package
	for each subP in p.packages
	    recPros subP
	next
end sub

sub main()
	' Show and clear the script output window
	Repository.EnsureOutputVisible "Script"
	Repository.ClearOutput "Script"
	Repository.CreateOutputTab "Error"
	Repository.ClearOutput "Error"
		
	' Get the currently selected package in the tree to work on
	dim thePackage as EA.Package
	set thePackage = Repository.GetTreeSelectedPackage()
		
	if not thePackage is nothing and thePackage.ParentID <> 0 then
		Repository.WriteOutput "Script", Now & " Hovedpakke: " & thePackage.Name & " (" & thePackage.PackageGUID & ")", 0 
		
		recPros(thePackage)
		Repository.WriteOutput "Script", Now & " Finished, check the Error and Types tabs", 0 
		Repository.EnsureOutputVisible "Script"
	else
		' No package selected in the tree
		MsgBox( "This script requires a package to be selected in the Project Browser." & vbCrLf & _
			"Please select a package in the Project Browser and try again." )
	end if
end sub

main
