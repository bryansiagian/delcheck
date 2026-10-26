<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('retur', function (Blueprint $table) {
            $table->id();
            $table->string('nomor', 40)->unique();
            $table->foreignId('pesanan_id')->constrained('pesanan');
            $table->foreignId('laporan_id')->nullable()->constrained('laporan_barang')->nullOnDelete(); // opsional [TBC]
            $table->foreignId('retailer_id')->constrained('retailers');
            $table->foreignId('diajukan_oleh')->constrained('users');
            $table->text('alasan');
            // diajukan, dikonfirmasi_sales, menunggu_penjemputan, dijemput, diterima_gudang, selesai, ditolak
            $table->string('status', 30)->default('diajukan');

            $table->foreignId('dikonfirmasi_oleh')->nullable()->constrained('users')->nullOnDelete(); // Sales
            $table->timestamp('dikonfirmasi_at')->nullable();
            $table->text('alasan_ditolak')->nullable();                // BR-06

            $table->dateTime('jadwal_jemput')->nullable();
            $table->timestamp('dijemput_at')->nullable();
            $table->string('bukti_jemput')->nullable();                // foto/tanda tangan [ASUMSI]

            $table->timestamp('diterima_gudang_at')->nullable();
            $table->string('tindak_lanjut', 30)->nullable();           // restock, musnahkan, kembali_pemasok [TBC]
            $table->timestamp('selesai_at')->nullable();
            $table->timestamps();

            $table->index(['retailer_id', 'status']);
            $table->index(['status', 'created_at']);
        });

        Schema::create('item_retur', function (Blueprint $table) {
            $table->id();
            $table->foreignId('retur_id')->constrained('retur')->cascadeOnDelete();
            $table->foreignId('item_pesanan_id')->constrained('item_pesanan');
            $table->foreignId('produk_id')->constrained('produk');
            $table->unsignedInteger('qty');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('item_retur');
        Schema::dropIfExists('retur');
    }
};
