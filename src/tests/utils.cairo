use starknet::ContractAddress;

pub fn OWNER() -> ContractAddress {
    'owner'.try_into().unwrap()
}

pub fn ADMIN() -> ContractAddress {
    'admin'.try_into().unwrap()
}


pub fn TEST_USER() -> ContractAddress {
    'test_user'.try_into().unwrap()
}

pub fn MEMBER_ONE() -> ContractAddress {
    'member_one'.try_into().unwrap()
}
pub fn MEMBER_TWO() -> ContractAddress {
    'member_two'.try_into().unwrap()
}
