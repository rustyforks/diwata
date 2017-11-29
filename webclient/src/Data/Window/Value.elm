module Data.Window.Value exposing (Value(..), decoder, valueToString)

import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Extra
import Json.Decode.Pipeline as Pipeline exposing (custom, decode, required)
import Date exposing (Date)
import Date.Format

type Value
    = Nil
    | Bool Bool

    | Tinyint Int
    | Smallint Int
    | Int Int
    | Bigint Int

    | Float Float
    | Double Float

    | Char Char
    | Text String
    | Json String

    | Uuid String
    | Date Date
    | Time String
    | Timestamp Date
    | Blob (List Int)



decoder: Decoder Value
decoder =
     Decode.oneOf 
        [ nilDecoder
        , boolDecoder
        , tinyintDecoder
        , smallintDecoder
        , intDecoder
        , floatDecoder
        , doubleDecoder
        , charDecoder
        , textDecoder
        , jsonDecoder
        , dateDecoder
        , timeDecoder
        , timestampDecoder
        , uuidDecoder
        , blobDecoder
        ]


nilDecoder: Decoder Value
nilDecoder =
    Decode.string 
    |> Decode.andThen
        (\val ->
            case val of
                "Nil" -> Decode.succeed Nil
                _ -> Decode.fail "Expecting 'Nil'"
        )


boolDecoder: Decoder Value
boolDecoder = 
    decode Bool
        |> required "Bool" Decode.bool

tinyintDecoder: Decoder Value
tinyintDecoder =
    decode Tinyint
        |> required "Tinyint" Decode.int

smallintDecoder: Decoder Value
smallintDecoder =
    decode Smallint
    |> required "Smallint" Decode.int

intDecoder: Decoder Value
intDecoder =
    decode Int
    |> required "Int" Decode.int

floatDecoder: Decoder Value
floatDecoder =
    decode Float
    |> required "Float" Decode.float

doubleDecoder: Decoder Value
doubleDecoder =
    decode Double
    |> required "Double" Decode.float

charDecoder: Decoder Value
charDecoder = 
    decode Char
    |> required "Char" 
        (Decode.string
            |> Decode.andThen 
                (\s -> 
                    case (String.uncons s) of
                        Just (c,_) -> Decode.succeed c
                        Nothing -> Decode.fail "Can not be empty value in Char"
                )
        )

textDecoder: Decoder Value
textDecoder = 
    decode Text
    |> required "Text" Decode.string

jsonDecoder: Decoder Value
jsonDecoder = 
    decode Json
    |> required "Json" Decode.string

uuidDecoder: Decoder Value
uuidDecoder = 
    decode Uuid
    |> required "Uuid" Decode.string

blobDecoder: Decoder Value
blobDecoder =
    decode Blob
        |> required "Blob" (Decode.list Decode.int)

dateDecoder: Decoder Value
dateDecoder = 
    decode Date
    |> required "Date" dateValueDecoder

{-- the same as above only longer
dateDecoder: Decoder Value
dateDecoder = 
    Decode.field "Date" Decode.string
    |> Decode.andThen
        (\v -> 
            case Date.fromString v of
                Ok v -> Decode.succeed v
                Err e -> Decode.fail "Invalid date"
        )
    |> Decode.map Date
--}

timeDecoder: Decoder Value
timeDecoder = 
    decode Time
    |> required "Time" Decode.string

timestampDecoder: Decoder Value
timestampDecoder = 
    decode Timestamp
    |> required "Timestamp" dateValueDecoder


dateValueDecoder : Decoder Date
dateValueDecoder =
    Decode.string
    |> Decode.andThen
        (\v -> 
            case Date.fromString v of
                Ok v -> Decode.succeed v
                Err e -> Debug.log ("fail to decode date" ++ v ) Decode.fail ("Invalid date:" ++ e)
     )


{-| 
    make a string representation for the purpose of selected record.
    Support the most common primary key data_types for now 
--}
valueToString: Value -> String
valueToString value =
    case value of
        Nil -> ""
        Bool v -> toString v

        Tinyint v -> toString v
        Smallint v -> toString v
        Int v -> toString v
        Bigint v -> toString v
        
        Float v -> toString v
        Double v -> toString v

        Char v -> toString v
        Text v -> v
        Json v -> v

        Uuid v -> v
        Date v -> Date.Format.format "%Y-%m-%d" v
        Time v -> v
        Timestamp v -> Date.Format.format "%Y-%m-%d" v
        Blob v -> toString v


