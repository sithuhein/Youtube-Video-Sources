table 53105 "Chess Material Info"
{
    DataClassification = SystemMetadata;
    Caption = 'Chess Material Info';

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
        }
        field(2; "White Captures"; Text[100])
        {
            Caption = 'By White';
        }
        field(3; "Black Captures"; Text[100])
        {
            Caption = 'By Black';
        }
        field(4; "Balance"; Text[20])
        {
            Caption = 'Balance';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
    }
}
