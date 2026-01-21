# Stage 1: Build (ใช้ Image ที่มี Rust เพื่อ Compile โค้ด)
FROM rust:latest as builder

# สร้างโฟลเดอร์ทำงาน
WORKDIR /app

# ก๊อปปี้ไฟล์ Config ของโปรเจกต์ไป
COPY Cargo.toml Cargo.lock ./

# ก๊อปปี้ Source Code ไป
COPY src ./src
COPY public ./public

# สั่ง Build เป็นโหมด Release (เพื่อให้ทำงานเร็วสุดๆ)
# หมายเหตุ: ขั้นตอนนี้อาจจะนานหน่อยในครั้งแรก
RUN cargo build --release

# ---------------------------------------------------

# Stage 2: Run (ใช้ Image เล็กๆ เฉพาะสำหรับรันโปรแกรม)
FROM debian:bookworm-slim

# ลงตัวช่วยที่จำเป็น (OpenSSL สำหรับต่อ Database)
RUN apt-get update && apt-get install -y libssl-dev ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# ก๊อปปี้ไฟล์ที่ Compile เสร็จแล้วจาก Stage 1 มา
COPY --from=builder /app/target/release/my-shoe-shop ./my-shoe-shop

# ก๊อปปี้ไฟล์หน้าเว็บ (HTML/CSS/Images) มาด้วย
COPY --from=builder /app/public ./public

# เปิด Port 8080
EXPOSE 8080

# คำสั่งเมื่อเริ่มรัน Container
CMD ["./my-shoe-shop"]