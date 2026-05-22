///|
extern "js" fn get_current_date_js() -> String =
  #| () => {
  #|   const d = new Date();
  #|   const year = d.getFullYear();
  #|   const month = String(d.getMonth() + 1).padStart(2, '0');
  #|   const day = String(d.getDate()).padStart(2, '0');
  #|   return `${year}-${month}-${day}`;
  #| }

///|
pub fn get_current_date() -> String {
  get_current_date_js()
}

///|
extern "js" fn run_command_js(cmd : String) -> Int =
  #| (cmd) => {
  #|   try {
  #|     const execSync = require('child_process').execSync;
  #|     execSync(cmd, { stdio: 'inherit' });
  #|     return 0;
  #|   } catch (e) {
  #|     return e.status || 1;
  #|   }
  #| }

///|
pub fn run_command(cmd : String) -> Int {
  run_command_js(cmd)
}

