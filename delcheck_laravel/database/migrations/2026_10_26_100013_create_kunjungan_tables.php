<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Jadwal bersifat per minggu; hari kunjungan tidak tetap (K4)
        Schema::create('jadwal_kunjungan', function (Blueprint $table) {
            $table->id();
            $table->foreignId('sales_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('retailer_id')->constrained('retailers');
            $table->date('tanggal_kunjungan');
            $table->date('minggu_mulai');                              // Senin minggu terkait, memudahkan query per minggu
            $table->string('status', 20)->default('dijadwalkan');      // dijadwalkan, berlangsung, selesai, terlewat
            $table->string('asal_jadwal', 20)->default('disusun_sendiri'); // disusun_sendiri, ditetapkan, tambahan [TBC]
            $table->timestamp('mulai_at')->nullable();
            $table->timestamp('selesai_at')->nullable();
            $table->decimal('checkin_latitude', 10, 7)->nullable();    // [ASUMSI] check-in lokasi
            $table->decimal('checkin_longitude', 10, 7)->nullable();
            $table->string('alasan_terlewat')->nullable();
            $table->foreignId('dijadwalkan_ulang_dari')->nullable()->constrained('jadwal_kunjungan')->nullOnDelete();
            $table->timestamps();

            $table->index(['sales_id', 'tanggal_kunjungan']);
            $table->index(['sales_id', 'minggu_mulai']);
        });

        Schema::create('catatan_kunjungan', function (Blueprint $table) {
            $table->id();
            $table->foreignId('kunjungan_id')->constrained('jadwal_kunjungan')->cascadeOnDelete();
            $table->text('catatan')->nullable();
            $table->text('tindak_lanjut')->nullable();
            $table->foreignId('pesanan_id')->nullable()->constrained('pesanan')->nullOnDelete(); // pesanan dibuat saat kunjungan
            $table->timestamps();
        });

        // [TBC] hanya bila klien menetapkan target penjualan (UC-S07)
        Schema::create('target_penjualan', function (Blueprint $table) {
            $table->id();
            $table->foreignId('sales_id')->constrained('users')->cascadeOnDelete();
            $table->date('periode_mulai');
            $table->date('periode_selesai');
            $table->decimal('target_nilai', 15, 2);
            $table->timestamps();

            $table->index(['sales_id', 'periode_mulai']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('target_penjualan');
        Schema::dropIfExists('catatan_kunjungan');
        Schema::dropIfExists('jadwal_kunjungan');
    }
};
