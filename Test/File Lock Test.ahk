; Creates a folder with a couple of empty files and locks some of them.

FileCreateDir, temp
FileCreateDir, temp\locked
FileCreateDir, temp\notlocked
FileAppend,, temp\locked\w
FileAppend,, temp\locked\r
FileAppend,, temp\locked\d
FileAppend,, temp\locked\wr
FileAppend,, temp\locked\wd
FileAppend,, temp\locked\rd
FileAppend,, temp\locked\rwd

FileAppend,, temp\notlocked\w
FileAppend,, temp\notlocked\r

FileAppend,, temp\notlocked\wr

w := FileOpen("temp\locked\w", "w -w")
r := FileOpen("temp\locked\r", "w -r")
d := FileOpen("temp\locked\d", "w -d")
wr := FileOpen("temp\locked\wr", "w -w -r")
wd := FileOpen("temp\locked\wd", "w -w -d")
rd := FileOpen("temp\locked\rd", "w -r -d")
rwd := FileOpen("temp\locked\rwd", "w -r -w -d")

w2 := FileOpen("temp\notlocked\w", "w")
r2 := FileOpen("temp\notlocked\r", "w")
wr2 := FileOpen("temp\notlocked\wr", "w r") ;not showing up

MsgBox, Reload?
Reload