<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        $duplikat = DB::table('pengiriman')
            ->select('pesanan_id')
            ->groupBy('pesanan_id')
            ->havingRaw('COUNT(*) > 1')
            ->exists();

        if ($duplikat) {
            throw new \RuntimeException(
                'Migration dihentikan: terdapat beberapa pengiriman untuk satu pesanan. Rapikan data secara manual sebelum menambahkan unique constraint.',
            );
        }

        Schema::table('pengiriman', function (Blueprint $table) {
            $table->string('nama_pengemudi', 120)->nullable();
            $table->string('telepon_pengemudi', 30)->nullable();
            $table->string('nomor_kendaraan', 40)->nullable();
            $table->unique('pesanan_id');
        });

        // Status lama "dikirim" memang berarti kurir sudah berangkat.
        // Pemetaan ke "jalan" mempertahankan hak Retail untuk mengonfirmasi.
        DB::table('pengiriman')->where('status', 'dikirim')->update(['status' => 'jalan']);
    }

    public function down(): void
    {
        $adaDataBaru = DB::table('pengiriman')
            ->whereNotNull('nama_pengemudi')
            ->orWhereNotNull('telepon_pengemudi')
            ->orWhereNotNull('nomor_kendaraan')
            ->orWhere('status', 'kurir')
            ->exists();

        if ($adaDataBaru) {
            throw new \RuntimeException(
                'Rollback dihentikan agar data pengemudi/kendaraan dan status tahap baru tidak hilang.',
            );
        }

        DB::table('pengiriman')->where('status', 'jalan')->update(['status' => 'dikirim']);

        Schema::table('pengiriman', function (Blueprint $table) {
            $table->dropUnique('pengiriman_pesanan_id_unique');
            $table->dropColumn([
                'nama_pengemudi',
                'telepon_pengemudi',
                'nomor_kendaraan',
            ]);
        });
    }
};
