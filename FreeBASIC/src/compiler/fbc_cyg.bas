''	FreeBASIC - 32-bit BASIC Compiler.
''	Copyright (C) 2004-2007 The FreeBASIC development team.
''
''	This program is free software; you can redistribute it and/or modify
''	it under the terms of the GNU General Public License as published by
''	the Free Software Foundation; either version 2 of the License, or
''	(at your option) any later version.
''
''	This program is distributed in the hope that it will be useful,
''	but WITHOUT ANY WARRANTY; without even the implied warranty of
''	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
''	GNU General Public License for more details.
''
''	You should have received a copy of the GNU General Public License
''	along with this program; if not, write to the Free Software
''	Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA.


'' main module, Windows front-end
''
'' chng: sep/2004 written [v1ctor]


#include once "inc\fb.bi"
#include once "inc\fbc.bi"
#include once "inc\hlp.bi"

declare function makeImpLib _
	( _
		byval dllpath as zstring ptr, _
		byval dllname as zstring ptr _
	) as integer

''
'' globals
''
	dim shared rclist as TLIST

'':::::
private sub _setDefaultLibPaths

	fbcAddDefLibPath( "/usr/local/i686-pc-cygwin/lib" )
	fbcAddDefLibPath( "/usr/local/lib" )
	fbcAddDefLibPath( "/usr/lib" )
	fbcAddDefLibPath( "/usr/lib/w32api" )

end sub

'':::::
private function _linkFiles _
	( _
	) as integer

	dim as string ldpath, ldcline, dllname

	function = FALSE

    '' set path
	ldpath = fbGetPath( FB_PATH_BIN ) + "ld" + FB_HOST_EXEEXT

    if( hFileExists( ldpath ) = FALSE ) then
		errReportEx( FB_ERRMSG_EXEMISSING, ldpath, -1 )
		exit function
    end if

	'' add extension
	if( fbc.outaddext ) then
		select case fbGetOption( FB_COMPOPT_OUTTYPE )
		case FB_OUTTYPE_EXECUTABLE
			fbc.outname += ".exe"
		case FB_OUTTYPE_DYNAMICLIB
			fbc.outname += ".dll"
		end select
	end if

	'' set default subsystem mode
	if( len( fbc.subsystem ) = 0 ) then
		fbc.subsystem = "console"
	else
		if( fbc.subsystem = "gui" ) then
			fbc.subsystem = "windows"
		end if
	end if

	'' set script file and subsystem
	ldcline = "-T " + QUOTE + fbGetPath( FB_PATH_BIN ) + ("i386pe.x" + QUOTE + " -subsystem ") + fbc.subsystem

    if( fbGetOption( FB_COMPOPT_OUTTYPE ) = FB_OUTTYPE_DYNAMICLIB ) then
		''
		dllname = hStripPath( hStripExt( fbc.outname ) )

		'' create a dll
		ldcline += " --dll --enable-stdcall-fixup"

		'' add aliases for functions without @nn
		if( fbGetOption( FB_COMPOPT_NOSTDCALL ) ) then
	   		ldcline += " --add-stdcall-alias"
    	end if

		'' export all symbols declared as EXPORT
		ldcline += " --export-dynamic"

		'' set the entry-point
		ldcline += " -e _DllMainCRTStartup@12"

    else
    	'' tell LD to add all symbols declared as EXPORT to the symbol table
    	if( fbGetOption( FB_COMPOPT_EXPORT ) ) then
    		ldcline += " --export-dynamic"
    	end if

    end if

    if( len( fbc.mapfile ) > 0) then
        ldcline += " -Map " + fbc.mapfile
    end if

	if( fbGetOption( FB_COMPOPT_DEBUG ) = FALSE ) then
		if( fbGetOption( FB_COMPOPT_PROFILE ) = FALSE ) then
			ldcline += " -s"
		end if
	end if

	'' stack size
	ldcline += " --stack " + str( fbc.stacksize ) + "," + str( fbc.stacksize )

	'' add library paths
	ldcline += *fbcGetLibPathList( )

	'' crt entry
	dim as string libdir = fbGetPath( FB_PATH_LIB )
	if( fbGetOption( FB_COMPOPT_OUTTYPE ) = FB_OUTTYPE_DYNAMICLIB ) then
		ldcline += " " + QUOTE + libdir + (RSLASH + "crt0.o" + QUOTE + " ")
	else
        '' FIXME
		ldcline += " " + QUOTE + libdir + (RSLASH + "crt0.o" + QUOTE + " ")

		'' additional support for gmon
		if( fbGetOption( FB_COMPOPT_PROFILE ) ) then
			ldcline += QUOTE + libdir + (RSLASH + "gcrt0.o" + QUOTE + " ")
		end if

	end if

    '' add objects from output list
	dim as FBC_IOFILE ptr iof = listGetHead( @fbc.inoutlist )
	do while( iof <> NULL )
    	ldcline += QUOTE + iof->outf + (QUOTE + " ")
    	iof = listGetNext( iof )
    loop

    '' add objects from cmm-line
	dim as string ptr objf = listGetHead( @fbc.objlist )
	do while( objf <> NULL )
    	ldcline += QUOTE + *objf + (QUOTE + " ")
    	objf = listGetNext( objf )
    loop

    '' set executable name
    ldcline += "-o " + QUOTE + fbc.outname + QUOTE

    '' init lib group
    ldcline += " -( "

    '' add libraries from cmm-line and found when parsing
    ldcline += *fbcGetLibList( dllname )

	if( fbGetOption( FB_COMPOPT_NODEFLIBS ) = FALSE ) then
		'' rtlib initialization and termination
		ldcline += QUOTE + libdir + (RSLASH + "fbrt0.o" + QUOTE + " ")
	end if

    '' end lib group
    ldcline += "-) "

	'' crt end
    if( fbGetOption( FB_COMPOPT_OUTTYPE ) = FB_OUTTYPE_DYNAMICLIB ) then
        '' create the def list to use when creating the import library
        ldcline += " --output-def " + QUOTE + hStripFilename( fbc.outname ) + dllname + (".def" + QUOTE)
	end if

   	'' extra options
   	ldcline += fbc.extopt.ld

    '' invoke ld
    if( fbc.verbose ) then
    	print "linking: ", ldcline
    end if

    if( exec( ldpath, ldcline ) <> 0 ) then
		exit function
    end if

    if( fbGetOption( FB_COMPOPT_OUTTYPE ) = FB_OUTTYPE_DYNAMICLIB ) then
		'' create the import library for the dll built
		if( makeImpLib( hStripFilename( fbc.outname ), dllname ) = FALSE ) then
			exit function
		end if
	end if

    function = TRUE

end function

'':::::
private function _archiveFiles( byval cmdline as zstring ptr ) as integer
	dim arcpath as string

	arcpath = fbGetPath( FB_PATH_BIN ) + "ar" + FB_HOST_EXEEXT

    if( exec( arcpath, *cmdline ) <> 0 ) then
		return FALSE
    end if

	return TRUE

end function

'':::::
private function _compileResFiles _
	( _
	) as integer

	dim as string rescmppath, rescmpcline, oldinclude

	function = FALSE

	'' replace the include env var
	oldinclude = trim( environ( "INCLUDE" ) )
	setenviron "INCLUDE=" + fbGetPath( FB_PATH_INC ) + "win" + RSLASH + "rc"

	''
	rescmppath = fbGetPath( FB_PATH_BIN ) + "GoRC.exe"

	'' set input files (.rc's and .res') and output files (.obj's)
	dim as string ptr rcf = listGetHead( @rclist )
	do while( rcf <> NULL )

		'' windres options
		rescmpcline = "/ni /nw /o /fo " + QUOTE + hStripExt( *rcf ) + _
					  (".obj" + QUOTE + " " + QUOTE) + *rcf + QUOTE

		'' invoke
		if( fbc.verbose ) then
			print "compiling resource: ", rescmpcline
		end if

		if( exec( rescmppath, rescmpcline ) <> 0 ) then
			exit function
		end if

		'' add to obj list
		dim as string ptr objf = listNewNode( @fbc.objlist )
		*objf = hStripExt( *rcf ) + ".obj"

		rcf = listGetNext( rcf )
	loop

	'' restore the include env var
	if( len( oldinclude ) > 0 ) then
		setenviron "INCLUDE=" + oldinclude
	end if

	function = TRUE

end function

'':::::
private function _delFiles as integer

	function = TRUE

end function

'':::::
private function _listFiles _
	( _
		byval argv as zstring ptr _
	) as integer

	select case hGetFileExt( argv )
	case "rc", "res"
		dim as string ptr rcf = listNewNode( @rclist )
		*rcf = *argv

		return TRUE

	case else
		return FALSE
	end select

end function

'':::::
private function _processOptions _
	( _
		byval opt as string ptr, _
		byval argv as string ptr _
	) as integer

    select case mid( *opt, 2 )
	case "s"
		if( argv = NULL ) then
			return FALSE
		end if

		fbc.subsystem = *argv
		if( len( fbc.subsystem ) = 0 ) then
			return FALSE
		end if
		return TRUE

	case "t"
		if( argv = NULL ) then
			return FALSE
		end if

		fbc.stacksize = valint( *argv ) * 1024
		if( fbc.stacksize < FBC_MINSTACKSIZE ) then
			fbc.stacksize = FBC_MINSTACKSIZE
		end if
		return TRUE

	case else
		return FALSE

	end select

end function

'':::::
function clearDefList( byval dllfile as zstring ptr ) as integer
	dim inpf as integer, outf as integer
	dim ln as string

	function = FALSE

    if( hFileExists( *dllfile + ".def" ) = FALSE ) then
    	exit function
    end if

    inpf = freefile
    open *dllfile + ".def" for input as #inpf
    outf = freefile
    open *dllfile + ".clean.def" for output as #outf

    '''''print #outf, "LIBRARY " + hStripPath( dllfile ) + ".dll"

    do until eof( inpf )

    	line input #inpf, ln

    	if( right( ln, 4 ) =  "DATA" ) then
    		ln = left( ln, len( ln ) - 4 )
    	end if

    	print #outf, ln
    loop

    close #outf
    close #inpf

    kill( *dllfile + ".def" )
    name *dllfile + ".clean.def", *dllfile + ".def"

    function = TRUE

end function

'':::::
private function makeImpLib _
	( _
		byval dllpath as zstring ptr, _
		byval dllname as zstring ptr _
	) as integer

	dim as string dtpath, dtcline, dllfile

	function = FALSE

	'' set path
	dtpath = fbGetPath( FB_PATH_BIN ) + "dlltool" + FB_HOST_EXEEXT

    if( hFileExists( dtpath ) = FALSE ) then
		errReportEx( FB_ERRMSG_EXEMISSING, dtpath, -1 )
		exit function
    end if

	''
	dllfile = *dllpath + *dllname

	'' output def list
	'''''if( makeDefList( dllname ) = FALSE ) then
	'''''	exit function
	'''''end if

	'' for some weird reason, LD will declare all functions exported as if they were
	'' from DATA segment, causing an exception (UPPERCASE'd symbols assumption??)
	if( clearDefList( dllfile ) = FALSE ) then
		exit function
	end if

	dtcline = "--def " + QUOTE + dllfile + ".def" + QUOTE + _
			  " --dllname " + QUOTE + *dllname + ".dll" + QUOTE + _
			  " --output-lib " + QUOTE + *dllpath + "lib" + *dllname + (".dll.a" + QUOTE)

    if( fbc.verbose ) then
    	print "dlltool: ", dtcline
    end if

    if( exec( dtpath, dtcline ) <> 0 ) then
		exit function
    end if

	''
	kill( dllfile + ".def" )

    function = TRUE

end function

'':::::
function fbcInit_cygwin( ) as integer

    static as FBC_VTBL vtbl = _
    ( _
		@_processOptions, _
		@_listFiles, _
		@_compileResFiles, _
		@_linkFiles, _
		@_archiveFiles, _
		@_delFiles, _
		@_setDefaultLibPaths _
	)

	fbc.vtbl = vtbl

	''
	listNew( @rclist, FBC_INITARGS\4, len( string ) )

	return TRUE

end function

