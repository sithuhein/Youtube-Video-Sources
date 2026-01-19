table 56400 "Email Details"
{
    fields
    {
        field(1; Type; Option)
        {
            OptionMembers = Header,BodyPart;
        }
        field(2; HeaderKey; Text[200])
        {

        }
        field(3; LineNo; Integer)
        { }
        field(4; Value; Text[2048])
        {

        }
        field(5; Binary; Blob)
        {

        }
    }
    keys
    {
        key(PK; Type, HeaderKey, LineNo)
        {
            Clustered = true;
        }
    }
}