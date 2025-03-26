# Make sure following is executed in "blue" pane of PowerShell ISE
# while script is displayed in "white" pane
$editor = $psISE.CurrentFile.Editor
$editor.Text = $editor.Text -replace " {2,3}", "`r`n`r`n"
