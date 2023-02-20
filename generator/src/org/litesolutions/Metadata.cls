Class org.litesolutions.Metadata Extends %Library.RegisteredObject
{

Parameter Classes = "Name,Super,Abstract,Persistent,Final,Deprecated,Hidden,SqlTable,System,Ensemble";

Parameter Methods = "ClassName,Name,ClassMethod,Abstract,Deprecated,ReturnType,FormalSpec";

Parameter Properties = "ClassName,Name,Type";

ClassMethod Extract(folder = "/home/irisowner/metadata") As %Status
{
  
  Set tSC = $$$OK
  Try {
    Write !,"Exporting metadata",!
    
    Set version = $System.Version.GetMajor() _ "." _ $System.Version.GetMinor()

    Set folder = ##class(%File).NormalizeDirectory("metadata/" _ version, folder)
    If ('##class(%File).DirectoryExists(folder)) {
      If ('##class(%File).CreateDirectoryChain(folder)) {
        Throw ##class(%Exception.General).%New("Can't create directory: "_folder)
      }
    }
    Write !,"Starting exporting to: "_folder
    Do ##class(%File).Delete(folder_"*")

    Set %classesStream = ##class(%Stream.FileCharacter).%New()  
    Set fileName = ##class(%File).NormalizeFilename("classes.csv", folder)
    $$$ThrowOnError(%classesStream.LinkToFile(fileName))
    Do %classesStream.WriteLine(..#Classes)

    Set %methodsStream = ##class(%Stream.FileCharacter).%New()  
    Set fileName = ##class(%File).NormalizeFilename("methods.csv", folder)
    $$$ThrowOnError(%methodsStream.LinkToFile(fileName))  
    Do %methodsStream.WriteLine(..#Methods)

    Set %propertiesStream = ##class(%Stream.FileCharacter).%New()  
    Set fileName = ##class(%File).NormalizeFilename("properties.csv", folder)
    $$$ThrowOnError(%propertiesStream.LinkToFile(fileName))  
    Do %propertiesStream.WriteLine(..#Properties)

    Set namespaces = $ListBuild("%SYS") _ $Select( $ZVersion["IRIS": $ListBuild("USER", "HSLIB", "HSSYS"), 1: $ListBuild("ENSEMBLE"))
    Set ptr = 0 
    While $ListNext(namespaces, ptr, namespace) {
      $$$ThrowOnError(..ExtractClasses(namespace, .allClasses))
    }

    $$$ThrowOnError(%classesStream.%Save())
    $$$ThrowOnError(%methodsStream.%Save())
    $$$ThrowOnError(%propertiesStream.%Save())
    Write !,"Successfully exported"
    Write !,"classes: ",%classesStream.Size
    Write !,"methods: ",%methodsStream.Size
    Write !,"properties: ",%propertiesStream.Size
  } Catch (ex) {
    Write !,"Error:",!
    Do ex.OutputToDevice()
    Set tSC = ex.AsStatus()
  }
  Quit tSC
}

ClassMethod ExtractClasses(namespace = {$Namespace}, ByRef unique) As %Status
{
  #define bool(%v) $Select(%v: "TRUE", 1: "")

  Set queue = $System.WorkMgr.Initialize("/multicompile=1",.sc)
  $$$ThrowOnError(sc)

  $$$ThrowOnError(..CollectClasses(namespace, .list, .unique))
  For i=1:1:list {
    Set className = list(i)
    $$$ThrowOnError(queue.QueueCallback("..ProcessClass", "..CallBack", namespace, className))
  }

  $$$ThrowOnError(queue.WaitForComplete())

  Quit $$$OK
}

ClassMethod CollectClasses(namespace = {$Namespace}, Output list = 0, ByRef unique) As %Status
{
  Set tSC = $$$OK
  
  New $Namespace
  Set $Namespace = namespace
  Set sys = ($Namespace = "%SYS")
  Set rs = ##class(%Dictionary.CompiledClassQuery).SummaryFunc()
  Set list = 0
  While rs.%Next() {
    Set className = rs.Name
    Continue:className=..%ClassName(1)
    Continue:('sys)&&($Extract(className)="%")
    Continue:$Piece(className,".")="INFORMATION"
    Continue:$Piece(className,".")="%cspapp"
    Continue:$Data(unique(className))
    Set unique(className) = ""
    
    Set list($Increment(list)) = className
  }

  Return tSC
}

ClassMethod CallBack(namespace, className) As %Status
{
  Set tSC = $$$OK

  Set row = $Get(^CacheTemp.Metadata(className))
  Do %classesStream.WriteLine($ListToString(row, ","))

  Set method = "", methods = 0
  For {
    Set method = $Order(^CacheTemp.Metadata(className, "methods", method), 1, row)
    Quit:method=""
    Do %methodsStream.WriteLine($ListToString(row, ","))
    Set methods = methods + 1
  }
  
  Set property = "", properties = 0
  For {
    Set property = $Order(^CacheTemp.Metadata(className, "properties", property), 1, row)
    Quit:property=""
    Do %propertiesStream.WriteLine($ListToString(row, ","))
    Set properties = properties + 1
  }

  #; Write !,className
  #; Write:methods "; Methods = ",methods
  #; Write:properties "; Properties = ",properties
  
  Kill ^CacheTemp.Metadata(className)
  Return tSC
}

ClassMethod ProcessClass(namespace = {$Namespace}, className As %String = "") As %Status
{
  Set tSC = $$$OK
  New $Namespace
  Set $Namespace = namespace

  Set sys = ($Namespace = "%SYS")

  Set classDef = ##class(%Dictionary.CompiledClass).%OpenId(className, 0)
  if '$ISOBJECT(classDef) {
    Write !,"Cannot open compiled class: ", className
    Quit tSC
  }
  
  Set super = classDef.Super
  Set super = $Translate(super, ",", "~")

  Set abstract = +classDef.Abstract
  Set final = +classDef.Final
  Set persistent = (classDef.ClassType = "persistent")
  Set deprecated = 0
  #If $System.Version.GetMajor()_"."_$System.Version.GetMinor()]]"2016.1"
  Set deprecated = classDef.Deprecated
  #EndIf
  Set hidden = classDef.Hidden

  Set system = sys && ($Extract(className) '= "%")
  Set ensemble = $ListFind($ListBuild("CSPX", "Ens", "EnsLib", "EnsPortal"), $Piece(className, "."))>0
  
  Set sqlTable = $Select(persistent: classDef.SqlSchemaName _ "." _ classDef.SqlTableName, 1: "")
  
  Set row = $ListBuild(
      className, 
      super,
      $$$bool(abstract), 
      $$$bool(persistent), 
      $$$bool(final), 
      $$$bool(deprecated), 
      $$$bool(hidden), 
      sqlTable, 
      $$$bool(system), 
      $$$bool(ensemble)
    )
  
  Set ^CacheTemp.Metadata(className) = row

  Try {
    $$$ThrowOnError(..ExtractMethods(classDef))
  } Catch error {
    Set ^CacheTemp.Metadata(className, "methods", "error"_$Increment(^CacheTemp.Metadata(className, "methods", "error"))) = $ListBuild(error.DisplayString())
  }
  Try {
    $$$ThrowOnError(..ExtractProperties(classDef))
  } Catch error {

  }
  
  Return tSC
}

ClassMethod ExtractMethods(classDef As %Dictionary.CompiledClass) As %Status
{
  Set tSC = $$$OK
  Set className = classDef.Name
  Set super = classDef.PrimarySuper
  Set super = $ZStrip(super, "<>P")
  Set super = $ListFromString($Piece(super, "~", 2, *), "~")
  Set key = ""
  For {
    Set methodDef = classDef.Methods.GetNext(.key)
    Quit:key=""
    Set methodName = methodDef.Name

    #; Continue:$Match(methodName, "^.*Get$")
    #; Continue:$Match(methodName, "^.*Set$")

    #; We don't need ClientMethods
    Continue:methodDef.ClientMethod
    #; Continue:(methodDef.Language'="")&&(methodDef.Language'="objectscript")&&(methodDef.Language'="cache")
    
    Continue:(methodDef.Origin'="")&&(methodDef.Origin'=className)
    
    Set skip = ""
    #; Skip overriden
    For i=1:1:$ListLength(super) {
      Set superClass = $ListGet(super,i)
      Continue:'##class(%Dictionary.CompiledMethod).%ExistsId(superClass _ "||" _ methodName)
      Set skip = superClass
      Quit
    }
    Continue:skip'=""

    Set classMethod = +methodDef.ClassMethod
    Set abstract = +methodDef.Abstract
    Set deprecated = 0
    #If $System.Version.GetMajor()_"."_$System.Version.GetMinor()]]"2016.1"
    Set deprecated = +methodDef.Deprecated
    #EndIf
    Set returnType = methodDef.ReturnType
    Set formalSpec = methodDef.FormalSpec
    Set formalSpec = $Translate(formalSpec, ",", "~")

    Set row = $ListBuild(
        className, 
        methodName, 
        $$$bool(classMethod), 
        $$$bool(abstract), 
        $$$bool(deprecated), 
        returnType,
        formalSpec
      )
    
    Set ^CacheTemp.Metadata(className, "methods", methodName) = row
  }

  Return tSC
}

ClassMethod ExtractProperties(classDef As %Dictionary.CompiledClass) As %Status
{
  Set tSC = $$$OK

  Set className = classDef.Name
  Set key = ""
  For {
    Set propertyDef = classDef.Properties.GetNext(.key)
    Quit:key=""
    Set propertyName = propertyDef.Name

    Set type = propertyDef.Type

    Set row = $ListBuild(className, propertyName, type)

    Set ^CacheTemp.Metadata(className, "properties", propertyName) = row
  }

  
  Return tSC
}

}
