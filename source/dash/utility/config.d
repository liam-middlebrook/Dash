/**
 * Defines the static class Config, which handles all configuration options.
 */
module dash.utility.config;
import dash.components.component;
import dash.utility.resources, dash.utility.output;

public import yaml;

import std.variant, std.algorithm, std.traits, std.range,
       std.array, std.conv, std.file, std.typecons, std.path;

private string fileToYaml( string filePath ) { return filePath.relativePath( getcwd() ).replace( "\\", "/" ).replace( "../", "" ).replace( "/", "." ).replace( ".yml", "" ); }

/**
 * Place this mixin anywhere in your game code to allow the Content.yml file
 * to be imported at compile time. Note that this will only actually import
 * the file when EmbedContent is listed as a defined version.
 */
mixin template ContentImport()
{
    version( EmbedContent )
    {
        static this()
        {
            import dash.utility.config;
            contentYML = import( "Content.yml" );
        }
    }
}

/// The node config values are stored.
Node config;
/// The constructor used to load load new yaml files.
Constructor constructor;
/// The string to store imported yaml content in.
version( EmbedContent ) string contentYML;
private Node contentNode;
/// The file storing config.
private Resource configFile = Resource( "" );

/// Initializes contentNode and constructor.
static this()
{
    constructor = new Constructor;
    contentNode = Node( YAMLNull() );

    import dash.components.lights;
    import dash.graphics.shaders.shaders;
    import dash.utility.output;
    import gl3n.linalg;

    constructor.addConstructorScalar( "!Vector2", ( ref Node node )
    {
        vec2 result;
        string[] vals = node.as!string.split();
        if( vals.length != 2 )
            throw new Exception( "Invalid number of values: " ~ node.as!string );

        result.x = vals[ 0 ].to!float;
        result.y = vals[ 1 ].to!float;
        return result;
    } );
    constructor.addConstructorScalar( "!Vector3", ( ref Node node )
    {
        vec3 result;
        string[] vals = node.as!string.split();
        if( vals.length != 3 )
            throw new Exception( "Invalid number of values: " ~ node.as!string );

        result.x = vals[ 0 ].to!float;
        result.y = vals[ 1 ].to!float;
        result.z = vals[ 2 ].to!float;
        return result;
    } );
    constructor.addConstructorScalar( "!Quaternion", ( ref Node node )
    {
        quat result;
        string[] vals = node.as!string.split();
        if( vals.length != 3 )
            throw new Exception( "Invalid number of values: " ~ node.as!string );

        result.x = vals[ 0 ].to!float;
        result.y = vals[ 1 ].to!float;
        result.z = vals[ 2 ].to!float;
        result.w = vals[ 3 ].to!float;
        return result;
    } );
    constructor.addConstructorScalar( "!Verbosity", &constructConv!Verbosity );
    constructor.addConstructorScalar( "!Shader", ( ref Node node ) => Shaders.get( node.get!string ) );
    //constructor.addConstructorScalar( "!Texture", ( ref Node node ) => Assets.get!Texture( node.get!string ) );
    //constructor.addConstructorScalar( "!Mesh", ( ref Node node ) => Assets.get!Mesh( node.get!string ) );
    //constructor.addConstructorScalar( "!Material", ( ref Node node ) => Assets.get!Material( node.get!string ) );
}

/**
 * Process all yaml files in a directory.
 *
 * Params:
 *  folder =                The folder to iterate over.
 */
Tuple!( Node, Resource )[] loadYamlFiles( string folder )
{
    Tuple!( Node, Resource )[] nodes;

    if( contentNode.isNull )
    {
        // Actually scan directories
        foreach( file; scanDirectory( folder, "*.yml" ) )
        {
            auto loader = Loader( file.fullPath );
            loader.constructor = constructor;

            try
            {
                // Iterate over all documents in a file
                foreach( doc; loader )
                {
                    nodes ~= tuple( doc, file );
                }
            }
            catch( YAMLException e )
            {
                logFatal( "Error parsing file ", file.baseFileName, ": ", e.msg );
            }
        }
    }
    else
    {
        auto fileNode = contentNode.find( folder.fileToYaml );

        foreach( string fileName, Node fileContent; fileNode )
        {
            if( fileContent.isSequence )
            {
                foreach( Node childChild; fileContent )
                    nodes ~= tuple( childChild, configFile );
            }
            else if( fileContent.isMapping )
            {
                nodes ~= tuple( fileContent, configFile );
            }
        }
    }

    return nodes;
}

/**
 * Process all documents files in a directory.
 *
 * Params:
 *  folder =                The folder to iterate over.
 */
Node[] loadYamlDocuments( string path )
{
    return loadYamlFiles( path ).map!( tup => tup[ 0 ] ).array;
}

/**
 * Processes all yaml files in a directory, and converts each document into an object of type T.
 *
 * Params:
 *  folder =            The folder to look in.
 */
T[] loadYamlObjects( T )( string folder )
{
    return folder.loadYamlDocuments.map!(yml => yml.getObject!T() );
}

/**
 * Load a yaml file with the engine-specific mappings.
 *
 * Params:
 *  filePath =              The path to file to load.
 */
Node loadYamlFile( string filePath )
{
    if( contentNode.isNull )
    {
        auto loader = Loader( filePath );
        loader.constructor = constructor;
        try
        {
            return loader.load();
        }
        catch( YAMLException e )
        {
            logFatal( "Error parsing file ", Resource( filePath ).baseFileName, ": ", e.msg );
            return Node();
        }
    }
    else
    {
        return contentNode.find( filePath.fileToYaml );
    }
}

/**
 * Load a yaml file with the engine-specific mappings.
 *
 * Params:
 *  filePath =              The path to file to load.
 */
Node[] loadAllDocumentsInYamlFile( string filePath )
{
    if( contentNode.isNull )
    {
        auto loader = Loader( filePath );
        loader.constructor = constructor;
        try
        {
            Node[] nodes;
            foreach( document; loader )
                nodes ~= document;
            return nodes;
        }
        catch( YAMLException e )
        {
            logFatal( "Error parsing file ", Resource( filePath ).baseFileName, ": ", e.msg );
            return [];
        }
    }
    else
    {
        return contentNode.find( filePath.fileToYaml ).get!( Node[] );
    }
}

/**
 * Refreshs a set of objects based on yaml files.
 *
 * Params:
 *  createFunc =        The function used to create a new object of type ObjectType.
 *  existsFunc =        The function that checks if a node is already stored. Returns a pointer to the object.
 *  addToResourcesFunc =Adds the
 *  ObjectType =        The type of object stored in YAML.
 *  objectResources =   The map of files to the objects they store.
 */
void refreshYamlObjects( alias createFunc, alias existsFunc, alias addToResourcesFunc, alias removeFunc, ObjectType )( ref ObjectType[][Resource] objectResources )
{
    // Disable refreshing YAML from a single file.
    if( !contentNode.isNull )
        return;

    // Iterate over each file, and it's objects
    foreach( file, ref objs; objectResources.dup )
    {
        // If the file was deleted, remove all objects in it.
        if( !file.exists )
        {
            foreach( asset; objs )
            {
                static if( __traits( compiles, asset.shutdown() ) )
                    asset.shutdown();
                removeFunc( asset );
            }

            objs = [];
        }
        // Else if the file changed, update each material.
        else if( file.needsRefresh )
        {
            // For each material, whether or not it still exists
            bool[ObjectType] objsFound = objs.zip( false.repeat( objs.length ) ).assocArray();

            // Reset objectResources for this file
            objs = [];

            // Foreach material currently in the file
            foreach( node; loadAllDocumentsInYamlFile( file.fullPath ) )
            {
                // If the material already existed, update it.
                if( auto oldMat = existsFunc( node ) )
                {
                    // If is pointer, dereference
                    static if( isPointer!( typeof(oldMat) ) )
                        auto mat = *oldMat;
                    else
                        auto mat = oldMat;

                    if( mat.yaml != node )
                    {
                        static if( __traits( compiles, mat.refresh( node ) ) )
                            mat.refresh( node );
                        else
                            refreshYamlObject[ typeid(mat) ]( mat, node );
                        mat.yaml = node;
                    }

                    objsFound[ mat ] = true;
                    objectResources[ file ] ~= mat;
                }
                // Else add new objects
                else
                {
                    auto newMat = createFunc( node );
                    addToResourcesFunc( node, newMat );
                    objectResources[ file ] ~= newMat;
                }
            }

            foreach( mat; objsFound.keys.filter!( object => !objsFound[ object ] ) )
            {
                static if( __traits( compiles, mat.shutdown() ) )
                    mat.shutdown();
                removeFunc( mat );
            }
        }
    }
}

/**
 * Get the element, cast to the given type, at the given path, in the given node.
 *
 * Params:
 *  node =          The node to search.
 *  path =          The path to find the item at.
 */
final T find( T = Node )( Node node, string path )
{
    T temp;
    if( node.tryFind( path, temp ) )
        return temp;
    else
        throw new YAMLException( "Path " ~ path ~ " not found in the given node." );
}
///
unittest
{
    import std.stdio;
    import std.exception;

    writeln( "Dash Config find unittest" );

    auto n1 = Node( [ "test1": 10 ] );

    assert( n1.find!int( "test1" ) == 10, "Config.find error." );

    assertThrown!YAMLException(n1.find!int( "dontexist" ));

    // nested test
    auto n2 = Node( ["test2": n1] );
    auto n3 = Node( ["test3": n2] );

    assert( n3.find!int( "test3.test2.test1" ) == 10, "Config.find nested test failed");

    auto n4 = Loader.fromString(
        "test3:\n" ~
        "   test2:\n" ~
        "       test1: 10" ).load;
    assert( n4.find!int( "test3.test2.test1" ) == 10, "Config.find nested test failed");
}

/**
 * Try to get the value at path, assign to result, and return success.
 *
 * Params:
 *  node =          The node to search.
 *  path =          The path to look for in the node.
 *  result =        [ref] The value to assign the result to.
 *
 * Returns: Whether or not the path was found.
 */
final bool tryFind( T )( Node node, string path, ref T result ) nothrow @safe
{
    // If anything goes wrong, it means the node wasn't found.
    scope( failure ) return false;

    Node res;
    bool found = node.tryFind( path, res );

    if( found )
    {
        static if( !isSomeString!T && is( T U : U[] ) )
        {
            assert( res.isSequence, "Trying to access non-sequence node " ~ path ~ " as an array." );

            foreach( Node element; res )
                result ~= element.get!U;
        }
        else static if( __traits( compiles, res.getObject!T ) )
        {
            result = res.getObject!T;
        }
        else
        {
            result = res.get!T;
        }
    }

    return found;
}

/// ditto
final bool tryFind( T: Node )( Node node, string path, ref T result ) nothrow @safe
{
    // If anything goes wrong, it means the node wasn't found.
    scope( failure ) return false;

    Node current;
    string left;
    string right = path;

    for( current = node; right.length; )
    {
        auto split = right.countUntil( '.' );

        if( split == -1 )
        {
            left = right;
            right.length = 0;
        }
        else
        {
            left = right[ 0..split ];
            right = right[ split + 1..$ ];
        }

        if( !current.isMapping || !current.containsKey( left ) )
            return false;

        current = current[ left ];
    }

    result = current;

    return true;
}

/// ditto
final bool tryFind( T = Node )( Node node, string path, ref Variant result ) nothrow @safe
{
    // Get the value
    T temp;
    bool found = node.tryFind( path, temp );

    // Assign and return results
    if( found )
        result = temp;

    return found;
}

/**
 * You may not get a variant from a node. You may assign to one,
 * but you must specify a type to search for.
 */
@disable bool tryFind( T: Variant )( Node node, string path, ref Variant result );

unittest
{
    import std.stdio;
    writeln( "Dash Config tryFind unittest" );

    auto n1 = Node( [ "test1": 10 ] );

    int val;
    assert( n1.tryFind( "test1", val ), "Config.tryFind failed." );
    assert( !n1.tryFind( "dontexist", val ), "Config.tryFind returned true." );
}

/**
 * Get element as a file path relative to the content home.
 *
 * Params:
 *  node =          The node to search for the path in.
 *  path =          The path to search the node for.
 *
 * Returns: The value at path relative to FilePath.ResourceHome.
 */
final string findPath( Node node, string path )
{
    return Resources.Home ~ node.find!string( path );//buildNormalizedPath( FilePath.ResourceHome, get!string( path ) );;
}

/**
 * Get a YAML map as a D object of type T.
 *
 * Params:
 *  T =             The type to get from the node.
 *  node =          The node to turn into the object.
 *
 * Returns: An object of type T that has all fields from the YAML node assigned to it.
 */
final T getObject( T )( Node node )
{
    T toReturn;

    static if( is( T == class ) )
        toReturn = new T;

    // Get each member of the type
    foreach( memberName; __traits(derivedMembers, T) )
    {
        // Make sure member is accessable
        enum protection = __traits( getProtection, __traits( getMember, toReturn, memberName ) );
        static if( protection == "public" || protection == "export" &&
                   __traits( compiles, isMutable!( __traits( getMember, toReturn, memberName ) ) ) )
        {
            // If it is a field and not a function, tryGet it's value
            static if( !__traits( compiles, ParameterTypeTuple!( __traits( getMember, toReturn, memberName ) ) ) &&
                       !__traits( compiles, isBasicType!( __traits( getMember, toReturn, memberName ) ) ) )
            {
                // Make sure member is mutable
                static if( isMutable!( typeof( __traits( getMember, toReturn, memberName ) ) ) )
                {
                    node.tryFind( memberName, __traits( getMember, toReturn, memberName ) );
                }
            }
            else
            {
                // Iterate over each overload of the function (common to have getter and setter)
                foreach( func; __traits( getOverloads, T, memberName ) )
                {
                    enum funcProtection = __traits( getProtection, func );
                    static if( funcProtection == "public" || funcProtection == "export" )
                    {
                        // Get the param types of the function
                        alias params = ParameterTypeTuple!func;

                        // If it can be a setter and is a property
                        static if( params.length == 1 && ( functionAttributes!func & FunctionAttribute.property ) )
                        {
                            // Else, set as temp
                            static if( is( params[ 0 ] == enum ) )
                            {
                                string tempValue;
                            }
                            else
                            {
                                params[ 0 ] otherTempValue;
                                auto tempValue = cast()otherTempValue;
                            }

                            if( node.tryFind( memberName, tempValue ) )
                                mixin( "toReturn." ~ memberName ) = tempValue.to!(params[0]);
                        }
                    }
                }
            }
        }
    }

    return toReturn;
}
unittest
{
    import std.stdio;
    writeln( "Dash Config getObject unittest" );

    auto t = Node( ["x": 5, "y": 7, "z": 9] ).getObject!Test();

    assert( t.x == 5 );
    assert( t.y == 7 );
    assert( t.z == 9 );
}
version(unittest) class Test
{
    int x;
    int y;
    private int _z;

    @property int z() { return _z; }
    @property void z( int newZ ) { _z = newZ; }
}

/**
 * Static class which handles the configuration options and YAML interactions.
 */
final abstract class Config
{
public static:
    /**
     * TODO
     */
    void initialize()
    {
        version( EmbedContent )
        {
            logDebug( "Using imported Content.yml file." );
            assert( contentYML, "EmbedContent version set, mixin not used." );
            auto loader = Loader.fromString( contentYML );
            loader.constructor = constructor;
            contentNode = loader.load();
            // Null content yml so it can be collected.
            contentYML = null;
        }
        else version( unittest )
        {
            auto loader = Loader.fromString( testYML );
            loader.constructor = constructor;
            contentNode = loader.load();
        }
        else
        {
            if( exists( Resources.CompactContentFile ) )
            {
                logDebug( "Using Content.yml file." );
                configFile = Resource( Resources.CompactContentFile );
                contentNode = Resources.CompactContentFile.loadYamlFile();
            }
            else
            {
                logDebug( "Using normal content directory." );
                configFile = Resource( Resources.ConfigFile );
            }
        }

        config = Resources.ConfigFile.loadYamlFile();
    }

    void refresh()
    {
        // No need to refresh, there can be no changes.
        version( EmbedContent ) { }
        else
        {
            if( exists( Resources.CompactContentFile ) )
            {
                logDebug( "Using Content.yml file." );
                if( configFile.needsRefresh )
                {
                    contentNode = Node( YAMLNull() );
                    contentNode = Resources.CompactContentFile.loadYamlFile();
                    config = Resources.ConfigFile.loadYamlFile();
                }
            }
            else
            {
                logDebug( "Using normal content directory." );
                if( configFile.needsRefresh )
                    config = Resources.ConfigFile.loadYamlFile();
            }
        }
    }
}

/**
 * TODO
 */
T constructConv( T )( ref Node node ) if( is( T == enum ) )
{
    if( node.isScalar )
    {
        return node.get!string.to!T;
    }
    else
    {
        throw new Exception( "Enum must be represented as a scalar." );
    }
}

version( unittest )
{
    import std.string;
    /// The string to store test yaml content in.
    string testYML = q{---
Config:
    Input:
        Forward:
            Keyboard: W
        Backward:
            Keyboard: S
        Jump:
            Keyboard: Space
    Config:
        Logging:
            FilePath: "dash.log"
            Debug:
                OutputVerbosity: !Verbosity Debug
                LoggingVerbosity: !Verbosity Debug
            Release:
                OutputVerbosity: !Verbosity Medium
                LoggingVerbosity: !Verbosity Medium
        Display:
            Fullscreen: false
            Height: 720
            Width: 1280
        Graphics:
            BackfaceCulling: true
            VSync: false
        Physics:
            Gravity: !Vector3 0.0 -10.0 0.0
        UserInterface:
            FilePath: "uitest.html"
            Scale: !Vector2 1.0 1.0
    };
}
