#![no_std]
#![no_main]
#![feature(const_in_array_repeat_expressions)]

use core::panic::PanicInfo;

mod kernel;

/// This function is called on panic.
#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
  loop {}
}

#[no_mangle]
pub extern "C" fn _start() -> ! {
  kernel::main()
}
