<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('retailers', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->nullable()->unique()->constrained('users')->nullOnDelete(); // akun login toko
            $table->foreignId('wilayah_id')->nullable()->constrained('wilayah')->nullOnDelete();
            $table->string('kode', 30)->unique();
            $table->string('nama_toko');
            $table->string('nama_pemilik')->nullable();
            $table->text('alamat');
            $table->string('telepon', 30)->nullable();
            $table->string('email')->nullable();
            $table->decimal('latitude', 10, 7)->nullable();  // untuk Sebaran Retail & check-in kunjungan
            $table->decimal('longitude', 10, 7)->nullable();
            $table->boolean('is_active')->default(true);

            // Verifikasi pendaftaran oleh Admin
            $table->string('status_verifikasi', 20)->default('menunggu'); // menunggu, disetujui, ditolak
            $table->foreignId('diverifikasi_oleh')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('diverifikasi_at')->nullable();
            $table->text('alasan_ditolak')->nullable();                   // BR-06
            $table->timestamps();
            $table->softDeletes();

            $table->index('nama_toko');
            $table->index('status_verifikasi');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('retailers');
    }
};
