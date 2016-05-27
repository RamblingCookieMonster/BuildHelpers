# Huge thanks to Joel Bennett for this.
# Sad that New-ModuleManifest PrivateData parameter can't handle this for us....

function Add-MetadataConverter {
   <#
      .Synopsis
         Add a converter functions for serialization and deserialization to metadata
      .Description
         Add-MetadataConverter allows you to map:
         * a type to a scriptblock which can serialize that type to metadata (psd1)
         * define a name and scriptblock as a function which will be whitelisted in metadata (for ConvertFrom-Metadata and Import-Metadata)
         The idea is to give you a way to extend the serialization capabilities if you really need to.
      .Example
         Add-MetadataCOnverter @{ [bool] = { if($_) { '$True' } else { '$False' } } }
         Shows a simple example of mapping bool to a scriptblock that serializes it in a way that's inherently parseable by PowerShell.  This exact converter is already built-in to the Metadata module, so you don't need to add it.
      .Example
         Add-MetadataConverter @{
            [Uri] = { "Uri '$_' " }
            "Uri" = {
               param([string]$Value)
               [Uri]$Value
            }
         }
         Shows how to map a function for serializing Uri objects as strings with a Uri function that just casts them. Normally you wouldn't need to do that for Uri, since they output strings natively, and it's perfectly logical to store Uris as strings and only cast them when you really need to.
      .Example
         Add-MetadataConverter @{
            [DateTimeOffset] = { "DateTimeOffset {0} {1}" -f $_.Ticks, $_.Offset }
            "DateTimeOffset" = {param($ticks,$offset) [DateTimeOffset]::new( $ticks, $offset )}   
         }
         Shows how to change the DateTimeOffset serialization.
         By default, DateTimeOffset values are (de)serialized using the 'o' RoundTrips formatting 
         e.g.: [DateTimeOffset]::Now.ToString('o')
   #>
   [CmdletBinding()]
   param(
      # A hashtable of types to serializer scriptblocks, or function names to scriptblock definitions
      [Parameter(Mandatory = $True)]
      [hashtable]$Converters
   )

   if($Converters.Count) {
      switch ($Converters.Keys.GetEnumerator()) {
         {$Converters.$_ -isnot [ScriptBlock]} {
            Write-Error "Ignoring $_ converter, value must be ScriptBlock"
            continue
         }

         {$_ -is [String]}
         {
            Write-Verbose "Adding function $_"
            Set-Content "function:script:$_" $Converters.$_
            # We need to store the given function name in MetadataConverters too
            $MetadataConverters.$_ = $Converters.$_
            continue
         }

         {$_ -is [Type]}
         {
            Write-Verbose "Adding serializer for $($_.FullName)"
            $MetadataConverters.$_ = $Converters.$_
            continue
         }

         default {
            Write-Error "Unsupported key type in Converters: $_ is $($_.GetType())"
         }
      }
   }
}

$MetadataConverters = @{}

if($Converters -is [Collections.IDictionary]) {
   Add-MetadataConverter $Converters
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