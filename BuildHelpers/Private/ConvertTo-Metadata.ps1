# Huge thanks to Joel Bennett for this.
# Sad that New-ModuleManifest PrivateData parameter can't handle this for us....

function ConvertTo-Metadata {
   #.Synopsis
   #  Serializes objects to PowerShell Data language (PSD1)
   #.Description
   #  Converts objects to a texual representation that is valid in PSD1,
   #  using the built-in registered converters (see Add-MetadataConverter).
   #
   #  NOTE: Any Converters that are passed in are temporarily added as though passed Add-MetadataConverter
   #.Example
   #  $Name = @{ First = "Joel"; Last = "Bennett" }
   #  @{ Name = $Name; Id = 1; } | ConvertTo-Metadata
   #
   #  @{
   #    Id = 1
   #    Name = @{
   #      Last = 'Bennett'
   #      First = 'Joel'
   #    }
   #  }
   #
   #  Convert input objects into a formatted string suitable for storing in a psd1 file.
   #.Example
   #  Get-ChildItem -File | Select-Object FullName, *Utc, Length | ConvertTo-Metadata
   #
   #  Convert complex custom types to dynamic PSObjects using Select-Object.
   #
   #  ConvertTo-Metadata understands PSObjects automatically, so this allows us to proceed
   #  without a custom serializer for File objects, but the serialized data 
   #  will not be a FileInfo or a DirectoryInfo, just a custom PSObject
   #.Example
   #  ConvertTo-Metadata ([DateTimeOffset]::Now) -Converters @{ 
   #     [DateTimeOffset] = { "DateTimeOffset {0} {1}" -f $_.Ticks, $_.Offset }
   #  }
   #
   #  Shows how to temporarily add a MetadataConverter to convert a specific type while serializing the current DateTimeOffset.
   #  Note that this serialization would require a "DateTimeOffset" function to exist in order to deserialize properly. 
   #
   #  See also the third example on ConvertFrom-Metadata and Add-MetadataConverter.
   [OutputType([string])]
   [CmdletBinding()]
   param(
      [Parameter(ValueFromPipeline = $True)]
      $InputObject,

      [Hashtable]$Converters = @{}
   )
   begin {
      $t = "  "
      $Script:OriginalMetadataConverters = $Script:MetadataConverters.Clone()
      Add-MetadataConverter $Converters
   }
   end {
      $Script:MetadataConverters = $Script:OriginalMetadataConverters.Clone()
   }
   process {
      # Write-verbose ("Type {0}" -f $InputObject.GetType().FullName)
      if($Null -eq $InputObject) {
        # Write-verbose "Null"
        '""'
      } elseif( $InputObject -is [Int16] -or
                $InputObject -is [Int32] -or
                $InputObject -is [Int64] -or
                $InputObject -is [Double] -or
                $InputObject -is [Decimal] -or
                $InputObject -is [Byte] )
      {
         # Write-verbose "Numbers"
         "$InputObject"
      }
      elseif($InputObject -is [String]) {
         "'{0}'" -f $InputObject.ToString().Replace("'","''") 
      }
      elseif($InputObject -is [Collections.IDictionary]) {
         # Write-verbose "Dictionary"
         #Write-verbose "Dictionary:`n $($InputObject|ft|out-string -width 110)"
         "@{{`n$t{0}`n}}" -f ($(
         ForEach($key in @($InputObject.Keys)) {
            if("$key" -match '^(\w+|-?\d+\.?\d*)$') {
               "$key = " + (ConvertTo-Metadata $InputObject.($key))
            }
            else {
               "'$key' = " + (ConvertTo-Metadata $InputObject.($key))
            }
         }) -split "`n" -join "`n$t")
      }
      elseif($InputObject -is [System.Collections.IEnumerable]) {
         # Write-verbose "Enumerable"
         "@($($(ForEach($item in @($InputObject)) { ConvertTo-Metadata $item }) -join ","))"
      }
      elseif($InputObject.GetType().FullName -eq 'System.Management.Automation.PSCustomObject') {
         # Write-verbose "PSCustomObject"
         # NOTE: we can't put [ordered] here because we need support for PS v2, but it's ok, because we put it in at parse-time
         "(PSObject @{{`n$t{0}`n}})" -f ($(
            ForEach($key in $InputObject | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name) {
               if("$key" -match '^(\w+|-?\d+\.?\d*)$') {
                  "$key = " + (ConvertTo-Metadata $InputObject.($key))
               }
               else {
                  "'$key' = " + (ConvertTo-Metadata $InputObject.($key))
               }
            }
         ) -split "`n" -join "`n$t")
      }
      elseif($MetadataConverters.ContainsKey($InputObject.GetType())) {
         $Str = ForEach-Object $MetadataConverters.($InputObject.GetType()) -InputObject $InputObject

         [bool]$IsCommand = & {
            $ErrorActionPreference = "Stop"
            $Tokens = $Null; $ParseErrors = $Null
            $AST = [System.Management.Automation.Language.Parser]::ParseInput( $Str, [ref]$Tokens, [ref]$ParseErrors)
            $Null -ne $Ast.Find({$args[0] -is [System.Management.Automation.Language.CommandAst]}, $false)
         }

         if($IsCommand) { "($Str)" } else { $Str }
      }
      else {
         # Write-verbose "Unknown!"
         # $MetadataConverters.Keys | %{ Write-Verbose "We have converters for: $($_.Name)" }
         Write-Warning "$($InputObject.GetType().FullName) is not serializable. Serializing as string"
         "'{0}'" -f $InputObject.ToString().Replace("'","`'`'")
      }
   }
}


<#
Copyright (c) 2015 Joel Bennett

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
#>