<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Satu pesanan bisa punya >1 pengiriman bila pengiriman parsial dipakai [TBC]
        Schema::create('pengiriman', function (Blueprint $table) {
            $table->id();
            $table->foreignId('pesanan_id')->constrained('pesanan')->cascadeOnDelete();
            $table->string('nomor_surat_jalan', 40)->nullable();
            $table->string('status', 20)->default('dikirim');   // dikirim, diterima
            $table->date('tanggal_kirim');
            $table->date('estimasi_tiba')->nullable();
            $table->timestamp('diterima_at')->nullable();
            $table->text('catatan')->nullable();
            $table->foreignId('diperbarui_oleh')->nullable()->constrained('users')->nullOnDelete(); // Admin
            $table->timestamps();

            $table->index(['pesanan_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('pengiriman');
    }
};
