use std::env;
use std::process;

use certs_downloader::Config;
use certs_downloader::download_certs;

fn main() {
    let args: Vec<String> = env::args().collect();
    let config = Config::build(&args).unwrap_or_else(|err| {
        eprintln!("{err}");
        process::exit(1);
    });

    match download_certs(&config) {
        Ok(_) => (),
        Err(err) => {
            eprintln!("download_certs failed: {:?}", err);
        }
    }
}
