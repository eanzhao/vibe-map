///|
#borrow(buf)
extern "C" fn get_current_date_c(buf : Bytes) = "get_current_date_c"

///|
pub fn get_current_date() -> String {
  let buf = Bytes::make(11, 0)
  get_current_date_c(buf)
  let sb = StringBuilder::new()
  for i = 0; i < 10; i = i + 1 {
    sb.write_char(buf[i].to_int().to_char().unwrap())
  }
  sb.to_string()
}

///|
#borrow(cmd)
extern "C" fn run_command_c(cmd : Bytes) -> Int = "run_command_c"

///|
pub fn run_command(cmd : String) -> Int {
  let len = cmd.length()
  let bytes = Bytes::makei(len + 1, fn(i) {
    if i < len {
      cmd[i].to_int().to_byte()
    } else {
      0
    }
  })
  run_command_c(bytes)
}

