table 53103 "Chess Move"
{
    DataClassification = SystemMetadata;
    Caption = 'Chess Move';

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
        }
        field(2; "Move No."; Integer)
        {
            Caption = '#';
        }
        field(3; "White Move"; Text[20])
        {
            Caption = 'White';
        }
        field(4; "Black Move"; Text[20])
        {
            Caption = 'Black';
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
