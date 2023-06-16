use reqwest::blocking::Client;
use serde::{Deserialize, Serialize};
use std::env;
use std::fs;
use std::io::Write;

const API_URL: &str = "https://dpm.unityfoundation.io/api";

struct Parameters {
    username: String,
    password: String,
    nonce: String,
    directory: String,
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() != 5 {
        println!("Usage: cargo run <username> <password> <nonce> <dir>");
        println!("The security documents will be stored in the <dir> directory!");
        return;
    }
    let para = Parameters {
        username: args[1].clone(),
        password: args[2].clone(),
        nonce: args[3].clone(),
        directory: args[4].clone(),
    };

    let result = download_certs(&para);
    match result {
        Ok(_) => (),
        Err(err) => {
            println!("download_certs failed: {:?}", err);
        }
    }
}

#[derive(Serialize, Deserialize)]
struct KeyPair {
    private: String,
    public: String,
}

fn download_certs(para: &Parameters) -> Result<(), Box<dyn std::error::Error>> {
    let client = Client::builder().cookie_store(true).build().unwrap();
    let login_url = format!("{}/login", API_URL);
    let credential = format!(
        "{{\"username\":\"{}\", \"password\":\"{}\"}}",
        para.username, para.password
    );
    let _auth_resp = client
        .post(login_url)
        .header(reqwest::header::CONTENT_TYPE, "application/json")
        .body(credential)
        .send();

    let base_url = format!("{}/applications", API_URL);
    download_cert(&client, &base_url, "identity_ca.pem", None, &para.directory)?;
    download_cert(
        &client,
        &base_url,
        "permissions_ca.pem",
        None,
        &para.directory,
    )?;
    download_cert(
        &client,
        &base_url,
        "governance.xml.p7s",
        None,
        &para.directory,
    )?;
    download_cert(
        &client,
        &base_url,
        "key_pair",
        Some(&para.nonce),
        &para.directory,
    )?;
    download_cert(
        &client,
        &base_url,
        "permissions.xml.p7s",
        Some(&para.nonce),
        &para.directory,
    )?;

    let kp_file = format!("{}/key_pair", para.directory);
    let kp_str = fs::read_to_string(kp_file)?;
    let kp: KeyPair = serde_json::from_str(&kp_str)?;

    let public_file = format!("{}/identity.pem", para.directory);
    let private_file = format!("{}/identity_key.pem", para.directory);
    fs::File::create(public_file)?.write_all(kp.public.as_bytes())?;
    fs::File::create(private_file)?.write_all(kp.private.as_bytes())?;
    Ok(())
}

fn download_cert(
    client: &Client,
    base_url: &str,
    filename: &str,
    nonce: Option<&str>,
    directory: &str,
) -> Result<(), Box<dyn std::error::Error>> {
    let url;
    if nonce.is_some() {
        url = format!("{}/{}?nonce={}", base_url, filename, nonce.unwrap());
    } else {
        url = format!("{}/{}", base_url, filename);
    }
    let body = client.get(&url).send()?.text()?;

    let path = format!("{}/{}", directory, filename);
    fs::create_dir_all(directory)?;
    let mut file = fs::File::create(path)?;
    file.write_all(body.as_bytes())?;
    Ok(())
}
