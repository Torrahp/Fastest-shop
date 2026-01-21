use actix_web::{web, App, HttpResponse, HttpServer, Responder};
use actix_files as fs;
use serde::Deserialize;
use sqlx::PgPool;
use std::env;

#[derive(Deserialize)]
struct LoginData {
    username: String,
    password: String,
}

// 🟢 โครงสร้างข้อมูลสินค้า
#[derive(Deserialize)]
struct CartItem {
    name: String,
    price: i32,
}

async fn login(form: web::Form<LoginData>, pool: web::Data<PgPool>) -> impl Responder {
    let query = "SELECT * FROM users WHERE username = $1 AND password = $2";
    let result = sqlx::query(query)
        .bind(&form.username)
        .bind(&form.password)
        .fetch_optional(pool.get_ref())
        .await;

    match result {
        Ok(Some(_)) => HttpResponse::SeeOther().append_header(("Location", "/index.html")).finish(),
        Ok(None) => HttpResponse::Unauthorized().body("Login Failed"),
        Err(_) => HttpResponse::InternalServerError().body("Database Error"),
    }
}

// 🟢 ฟังก์ชันชำระเงิน (รับข้อมูลจากหน้าเว็บมาบันทึก)
async fn checkout(cart: web::Json<Vec<CartItem>>, pool: web::Data<PgPool>) -> impl Responder {
    println!("💰 ได้รับออเดอร์: {} รายการ", cart.len());

    for item in cart.iter() {
        let query = "INSERT INTO orders (item_name, price) VALUES ($1, $2)";
        let _ = sqlx::query(query)
            .bind(&item.name)
            .bind(&item.price)
            .execute(pool.get_ref())
            .await;
    }

    println!("✅ บันทึกเสร็จเรียบร้อย!");
    HttpResponse::Ok().body("Order Saved")
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    // เช็ค Port ให้ตรงกับเครื่องคุณ (5433 หรือ 5432)
    let database_url = env::var("DATABASE_URL")
        .unwrap_or_else(|_| "postgres://postgres:password123@127.0.0.1:5433/postgres".to_string());

    println!("⏳ กำลังเชื่อมต่อ Database ที่: {}", database_url);

    let pool = PgPool::connect(&database_url).await.expect("ต่อ DB ไม่ติด!");

    println!("🚀 Server Ready at http://localhost:8080");

    HttpServer::new(move || {
        App::new()
            .app_data(web::Data::new(pool.clone()))
            .route("/login", web::post().to(login))
            .route("/checkout", web::post().to(checkout)) // เพิ่มเส้นทางนี้
            .service(fs::Files::new("/", "./public").index_file("login.html"))
    })
    .bind(("0.0.0.0", 8080))?
    .run()
    .await
}