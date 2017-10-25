use widget::Widget;

/// Intellisense module for the models
/// hints the client side renderer on which controls/widget appropriate to use
/// list of supported and recognized data in the system
/// Intellisense reference is gathered from
///  - table reference
///  - table name
///  - column name
///  - column datatype
///  - column data limit
///  - actual data content
#[derive(Debug, PartialEq)]
pub enum Reference {
    Person,
    Firstname,
    LastName,
    MiddleName,
    Salutation,
    EmailAddress,
    Username,
    CompanyName,
    Name, // generic name
    Password, // password control
    Tag,
    CountryName,
    CountryCode,
    Color,
    Shape,
    Timezone,

    Title,
    Description,

    PrimaryUserId, // user_id on users table
    PrimaryUserUuid, // user_id in uuid in users table
    ReferredUserId, // user_id referred from other table
    ReferredUserUuid,// referred user in uuid
    Created,
    Updated,
    Calendar,
    CalendarTime,

    Url,       //url links, could be linked/summarized (ie: starts with https:// and or wwww )
    VideoLink, // link to youtube videos
    ImageLink, // link to image, could be rehosted to avoid xss
    Tweet,     // linked to a tweet
    PopularService, // gmail, twitter, github, gitlab,
    MapLocation,
    Latitude,
    Longitude,

    Address, // a person real address, which could be located in the map
    Icon,    // icon, conveys meaning
    Logo,    // aesthetics images
    Image,   // potential to display as image
    Banner,  // Huge images for banner puposes

    ForeignReferredValueLookup, // could render the referenced data to here
    ImageForeignLookup, // foreign lookup with image rendered to help better recognize records
    ForeignIdentifiableValueLookup, // displays the identifiable record for the lookup

    Price,  // rendered as price or currency
    Symbol, // 1 character symbol such as currency symbol

    AuxilliaryAction,      // an action button
    PrimaryAction,         // a bigger button
    GenderSelection,       // Male/Female selection widget
    Toggle,                // bool, rendered as toggle button
    ChecklistItem,         // bool, most likely be rendered as checkbox
    BoolStatusReadOnly,    // most likely be check mark image that is read-only
    ActiveStatusIndicator, // green when active, gray or invisible when not
    SortOrder, // a column that describes the sort order of the item, if present then reordering capability will be displayed
    Selection, // bool, an item could be selected

    Enum(String, Vec<String>),// enum list

    MarkdownBlogEntry,    // a markdown formatted text content
    MarkdownCommentEntry, // a markdown formatted text comment
    Markdown,             // no specifics
    HtmlBlogEntry,        // a safe-html formatted text content
    HtmlCommentEntry,     // a safe-html formatted text comment
    JsonData,             // a json data entry
    XmlData,              // an xml formatted data
    SourceCode,           // an excerpt of source code
    SqlCode,              // a sql code
    CsvData,              // a data csv inside a value
    SvgImage,             // an svg image
    BinaryExecutable,     // an executable binary data
    Document(Document),

    Model3D, // a 3D object
    Video,   // a video
    Mp3Audio,

    IpAddress,
    DomainName,

    BitcoinAddress,
    EthereumAddress,
}

#[derive(Debug, PartialEq)]
pub enum Document {
    Pdf,
    Xls,
    Ods,
    Markdown,
    Svg,
    Txt,
    Csv,
    Xml,
    Archived,
}


impl Reference {
    fn use_widget_in_full_view(&self) -> Widget {
        match *self {
            Reference::Password => Widget::Password,
            Reference::MarkdownBlogEntry => Widget::MarkdownHtml,
            Reference::Enum(ref _name, ref choices) => {
                // if there are 2 choices, then it will be a radio group
                // if there are 3 choices, radio group
                // 4 choices, radio group
                // 5 or more it will be a dropdownlist
                match choices.len(){
                    1...4 => Widget::Radiogroup(choices.to_owned()),
                    _ => Widget::FixDropdown(choices.to_owned()),
                }
            }
            _ => Widget::Textbox,
        }
    }
}
