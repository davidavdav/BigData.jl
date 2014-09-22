## A data handle, either in memory or on disk, perhaps even mmapped but I haven't seen any 
## advantage of that.  It contains a list of either files (where the data is stored)
## or data units.  The point is, that in processing, these units can naturally be processed
## independently.  
type Data
    datatype::Type
    list::Vector
    read::Union(Function,Nothing)
end

typealias DataOrMatrix Union(Data, Matrix)
