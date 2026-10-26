<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('laporan_barang', function (Blueprint $table) {
            $table->id();
            $table->string('nomor', 40)->unique();
            $table->foreignId('pesanan_id')->constrained('pesanan');   // BR-04
            $table->foreignId('retailer_id')->constrained('retailers');
            $table->foreignId('dibuat_oleh')->constrained('users');
            $table->string('jenis_masalah', 30);   // rusak, kemasan_cacat, kedaluwarsa, salah_kirim, jumlah_tidak_sesuai [ASUMSI]
            $table->string('kategori_penyebab', 50)->nullable();       // untuk Akar Permasalahan [TBC: siapa yang menentukan]
            $table->text('deskripsi')->nullable();
            // dibuat, ditinjau, perlu_bukti_tambahan, disetujui, ditolak
            $table->string('status', 30)->default('dibuat');
            $table->foreignId('ditinjau_oleh')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('ditinjau_at')->nullable();
            $table->timestamps();

            $table->index(['retailer_id', 'status']);
            $table->index(['status', 'created_at']);
        });

        Schema::create('item_laporan', function (Blueprint $table) {
            $table->id();
            $table->foreignId('laporan_id')->constrained('laporan_barang')->cascadeOnDelete();
            $table->foreignId('item_pesanan_id')->constrained('item_pesanan');
            $table->foreignId('produk_id')->constrained('produk');
            $table->string('batch', 50)->nullable();                   // untuk Mutu Kemasan [TBC]
            $table->unsignedInteger('qty');
            $table->timestamps();
        });

        // Keputusan klaim oleh Warehouse (BR-03): satu laporan ke satu klaim
        Schema::create('klaim', function (Blueprint $table) {
            $table->id();
            $table->foreignId('laporan_id')->unique()->constrained('laporan_barang')->cascadeOnDelete();
            $table->string('keputusan', 20)->nullable();               // disetujui | ditolak
            $table->text('alasan')->nullable();                        // BR-06
            $table->string('kompensasi_jenis', 30)->nullable();        // ganti_barang, kredit, lainnya [TBC]
            $table->decimal('kompensasi_nilai', 15, 2)->nullable();
            $table->foreignId('diputuskan_oleh')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('diputuskan_at')->nullable();
            $table->timestamps();
        });

        // Foto bukti polimorfik: laporan barang, bukti jemput retur, dsb.
        Schema::create('foto_bukti', function (Blueprint $table) {
            $table->id();
            $table->morphs('fotoable');
            $table->string('path');
            $table->string('nama_asli')->nullable();
            $table->string('mime', 50)->nullable();
            $table->unsignedInteger('ukuran')->nullable();             // byte (NFR-10)
            $table->foreignId('diunggah_oleh')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('foto_bukti');
        Schema::dropIfExists('klaim');
        Schema::dropIfExists('item_laporan');
        Schema::dropIfExists('laporan_barang');
    }
};
