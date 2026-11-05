<?php

namespace App\Services;

use App\Enums\Peran;
use App\Enums\StatusPesanan;
use App\Enums\StatusRetur;
use App\Exceptions\ApiException;
use App\Models\AuditLog;
use App\Models\ItemPesanan;
use App\Models\ItemRetur;
use App\Models\Pesanan;
use App\Models\Retailer;
use App\Models\Retur;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Throwable;

class ReturService
{
    /** Relasi yang dimuat untuk detail hasil operasi. */
    public const MUAT = [
        'pesanan',
        'retailer',
        'pengaju',
        'dikonfirmasiOleh',
        'item.itemPesanan',
        'item.produk',
        'fotoBukti.pengunggah',
    ];

    /**
     * Buat draft satu produk dari pesanan yang sudah diterima.
     * Foto kondisi opsional selama masih draft, tetapi wajib saat diajukan.
     *
     * @param  array{pesanan_id: int, item_pesanan_id: int, qty: int, alasan: string, jenis_penyelesaian?: ?string}  $data
     * @param  array<int, UploadedFile>  $fotoKondisi
     */
    public function buatDraft(User $retail, array $data, array $fotoKondisi = []): Retur
    {
        $this->pastikanPeran($retail, Peran::Retail);
        $this->validasiDataDraft($data, true);
        $this->validasiFoto($fotoKondisi, 'foto_kondisi');

        $retailer = $this->retailerMilik($retail);
        $pathsBaru = [];

        try {
            return DB::transaction(function () use ($retail, $retailer, $data, $fotoKondisi, &$pathsBaru): Retur {
                $pesanan = $this->kunciPesananMilikRetail($data['pesanan_id'], $retailer);
                $itemPesanan = $this->itemPesananUntukOrder($data['item_pesanan_id'], $pesanan);
                $this->pastikanProdukBelumDiajukan($pesanan->id, $itemPesanan->produk_id);

                $retur = Retur::create([
                    'nomor' => 'TMP-'.Str::uuid(),
                    'pesanan_id' => $pesanan->id,
                    'retailer_id' => $retailer->id,
                    'diajukan_oleh' => $retail->id,
                    'alasan' => trim($data['alasan']),
                    'status' => StatusRetur::Draft,
                    'jenis_penyelesaian' => $data['jenis_penyelesaian'] ?? null,
                ]);

                $retur->update([
                    'nomor' => sprintf('RTR-%s-%05d', now()->format('Ymd'), $retur->id),
                ]);

                ItemRetur::create([
                    'retur_id' => $retur->id,
                    'item_pesanan_id' => $itemPesanan->id,
                    'produk_id' => $itemPesanan->produk_id,
                    'qty' => (int) $data['qty'],
                ]);

                $this->simpanFoto($retur, $fotoKondisi, 'kondisi_produk', $retail, $pathsBaru);

                AuditLog::catat($retur, 'retur_draft_dibuat', null, StatusRetur::Draft->value, null, [], $retail->id);

                return $retur->load(self::MUAT);
            });
        } catch (Throwable $exception) {
            $this->hapusBerkas($pathsBaru);

            throw $exception;
        }
    }

    /**
     * Ubah seluruh data draft. Jika $fotoKondisi null, foto lama dipertahankan;
     * jika array diberikan, daftar foto kondisi diganti dengan daftar tersebut.
     *
     * @param  array<string, mixed>  $data
     * @param  array<int, UploadedFile>|null  $fotoKondisi
     */
    public function perbaruiDraft(Retur $retur, User $retail, array $data, ?array $fotoKondisi = null): Retur
    {
        $this->pastikanPeran($retail, Peran::Retail);
        $this->validasiDataDraft($data, false);
        if ($fotoKondisi !== null) {
            $this->validasiFoto($fotoKondisi, 'foto_kondisi');
        }

        $retailer = $this->retailerMilik($retail);
        $pathsBaru = [];
        $pathsLama = [];

        try {
            $hasil = DB::transaction(function () use ($retur, $retail, $retailer, $data, $fotoKondisi, &$pathsBaru, &$pathsLama): Retur {
                $pesananAsalId = (int) $retur->pesanan_id;
                $pesananTujuanId = array_key_exists('pesanan_id', $data) ? (int) $data['pesanan_id'] : $pesananAsalId;
                $pesananTerkunci = Pesanan::query()
                    ->whereIn('id', array_values(array_unique([$pesananAsalId, $pesananTujuanId])))
                    ->orderBy('id')
                    ->lockForUpdate()
                    ->get()
                    ->keyBy('id');
                $pesananAsal = $pesananTerkunci->get($pesananAsalId);
                $pesananTujuan = $pesananTerkunci->get($pesananTujuanId);

                if (! $pesananAsal || (int) $pesananAsal->retailer_id !== (int) $retailer->id) {
                    throw new ApiException('Pesanan tidak ditemukan.', 404, 'PESANAN_TIDAK_DITEMUKAN');
                }
                if (! $pesananTujuan || (int) $pesananTujuan->retailer_id !== (int) $retailer->id) {
                    throw new ApiException('Pesanan tidak ditemukan.', 404, 'PESANAN_TIDAK_DITEMUKAN');
                }
                if ($pesananTujuan->status !== StatusPesanan::Diterima) {
                    throw ValidationException::withMessages(['pesanan_id' => 'Return hanya dapat dibuat dari pesanan yang sudah diterima.']);
                }

                $terkini = Retur::query()->lockForUpdate()->findOrFail($retur->id);
                if ((int) $terkini->pesanan_id !== $pesananAsalId) {
                    throw new ApiException('Draft Return berubah saat sedang diedit. Muat ulang sebelum mencoba lagi.', 409, 'DRAFT_RETUR_BERUBAH');
                }
                $this->pastikanPemilik($terkini, $retailer);
                $this->pastikanStatus($terkini, [StatusRetur::Draft]);

                $itemPesanan = $pesananTujuanId === $pesananAsalId && $terkini->item?->item_pesanan_id
                    ? ItemPesanan::query()->findOrFail($terkini->item->item_pesanan_id)
                    : null;

                if (array_key_exists('item_pesanan_id', $data)) {
                    $itemPesanan = $this->itemPesananUntukOrder($data['item_pesanan_id'], $pesananTujuan);
                }

                if (! $itemPesanan) {
                    throw ValidationException::withMessages([
                        'item_pesanan_id' => 'Item pesanan Return tidak tersedia.',
                    ]);
                }

                if ($pesananTujuanId !== $pesananAsalId && ! array_key_exists('item_pesanan_id', $data)) {
                    throw ValidationException::withMessages(['item_pesanan_id' => 'Pilih produk pada pesanan tujuan.']);
                }

                $this->pastikanProdukBelumDiajukan($pesananTujuanId, $itemPesanan->produk_id, $terkini->id);

                $pembaruan = [];
                if ($pesananTujuanId !== $pesananAsalId) {
                    $pembaruan['pesanan_id'] = $pesananTujuan->id;
                }
                if (array_key_exists('alasan', $data)) {
                    $pembaruan['alasan'] = trim((string) $data['alasan']);
                }
                if (array_key_exists('jenis_penyelesaian', $data)) {
                    $pembaruan['jenis_penyelesaian'] = $data['jenis_penyelesaian'];
                }
                if (array_key_exists('qty', $data)) {
                    $pembaruan['qty'] = (int) $data['qty'];
                }

                $terkini->update($pembaruan);
                if ($terkini->item->item_pesanan_id !== $itemPesanan->id) {
                    $terkini->item->update([
                        'item_pesanan_id' => $itemPesanan->id,
                        'produk_id' => $itemPesanan->produk_id,
                    ]);
                }
                if (array_key_exists('qty', $data)) {
                    $terkini->item->update(['qty' => (int) $data['qty']]);
                }

                if ($fotoKondisi !== null) {
                    $fotoLama = $terkini->fotoBukti()->where('jenis', 'kondisi_produk')->get();
                    $pathsLama = $fotoLama->pluck('path')->all();
                    $fotoLama->each->delete();
                    $this->simpanFoto($terkini, $fotoKondisi, 'kondisi_produk', $retail, $pathsBaru);
                }

                AuditLog::catat($terkini, 'retur_draft_diperbarui', StatusRetur::Draft->value, StatusRetur::Draft->value, null, [], $retail->id);

                return $terkini->load(self::MUAT);
            });
        } catch (Throwable $exception) {
            $this->hapusBerkas($pathsBaru);

            throw $exception;
        }

        $this->hapusBerkas($pathsLama);

        return $hasil;
    }

    /** Retail dapat menghapus hanya draft miliknya. */
    public function hapusDraft(Retur $retur, User $retail): void
    {
        $this->pastikanPeran($retail, Peran::Retail);
        $retailer = $this->retailerMilik($retail);
        $paths = [];

        DB::transaction(function () use ($retur, $retail, $retailer, &$paths): void {
            $this->kunciPesananMilikRetail($retur->pesanan_id, $retailer, false);
            $terkini = Retur::query()->lockForUpdate()->findOrFail($retur->id);
            $this->pastikanPemilik($terkini, $retailer);
            $this->pastikanStatus($terkini, [StatusRetur::Draft]);

            $foto = $terkini->fotoBukti()->get();
            $paths = $foto->pluck('path')->all();
            $foto->each->delete();

            AuditLog::catat($terkini, 'retur_draft_dihapus', StatusRetur::Draft->value, null, null, [], $retail->id);
            $terkini->delete();
        });

        $this->hapusBerkas($paths);
    }

    /** Retail mengajukan draft yang telah lengkap. */
    public function ajukan(Retur $retur, User $retail): Retur
    {
        $this->pastikanPeran($retail, Peran::Retail);
        $retailer = $this->retailerMilik($retail);

        return DB::transaction(function () use ($retur, $retail, $retailer): Retur {
            $this->kunciPesananMilikRetail($retur->pesanan_id, $retailer);
            $terkini = Retur::query()->lockForUpdate()->findOrFail($retur->id);
            $this->pastikanPemilik($terkini, $retailer);
            $this->pastikanStatus($terkini, [StatusRetur::Draft]);

            $item = $terkini->item;
            if (! $item || $item->qty < 1) {
                throw ValidationException::withMessages(['qty' => 'Kuantitas Return harus lebih dari 0.']);
            }
            if (trim((string) $terkini->alasan) === '') {
                throw ValidationException::withMessages(['alasan' => 'Alasan Return wajib diisi.']);
            }
            if (! in_array($terkini->jenis_penyelesaian, ['refund', 'replacement'], true)) {
                throw ValidationException::withMessages(['jenis_penyelesaian' => 'Pilih refund atau replacement.']);
            }
            if (! $terkini->fotoBukti()->where('jenis', 'kondisi_produk')->exists()) {
                throw ValidationException::withMessages(['foto_kondisi' => 'Unggah minimal satu foto kondisi produk.']);
            }

            $this->pastikanProdukBelumDiajukan($terkini->pesanan_id, $item->produk_id, $terkini->id);
            $terkini->update(['status' => StatusRetur::Diajukan]);

            AuditLog::catat($terkini, 'retur_diajukan', StatusRetur::Draft->value, StatusRetur::Diajukan->value, null, [], $retail->id);

            return $terkini->load(self::MUAT);
        });
    }

    /** Sales menyetujui satu pengajuan Return. */
    public function setujui(Retur $retur, User $sales): Retur
    {
        $this->pastikanPeran($sales, Peran::Sales);

        return DB::transaction(function () use ($retur, $sales): Retur {
            $terkini = Retur::query()->lockForUpdate()->findOrFail($retur->id);
            $this->pastikanStatus($terkini, [StatusRetur::Diajukan]);
            $terkini->update([
                'status' => StatusRetur::Disetujui,
                'dikonfirmasi_oleh' => $sales->id,
                'dikonfirmasi_at' => now(),
                'alasan_ditolak' => null,
            ]);

            AuditLog::catat($terkini, 'retur_disetujui', StatusRetur::Diajukan->value, StatusRetur::Disetujui->value, null, [], $sales->id);

            return $terkini->load(self::MUAT);
        });
    }

    /** Sales menolak satu pengajuan; alasan wajib dan status menjadi terminal. */
    public function tolak(Retur $retur, string $alasan, User $sales): Retur
    {
        $this->pastikanPeran($sales, Peran::Sales);
        $alasan = trim($alasan);
        if ($alasan === '') {
            throw ValidationException::withMessages(['alasan_ditolak' => 'Alasan penolakan wajib diisi.']);
        }

        return DB::transaction(function () use ($retur, $alasan, $sales): Retur {
            $terkini = Retur::query()->lockForUpdate()->findOrFail($retur->id);
            $this->pastikanStatus($terkini, [StatusRetur::Diajukan]);
            $terkini->update([
                'status' => StatusRetur::Ditolak,
                'dikonfirmasi_oleh' => $sales->id,
                'dikonfirmasi_at' => now(),
                'alasan_ditolak' => $alasan,
            ]);

            AuditLog::catat($terkini, 'retur_ditolak', StatusRetur::Diajukan->value, StatusRetur::Ditolak->value, $alasan, [], $sales->id);

            return $terkini->load(self::MUAT);
        });
    }

    /** Admin atau Warehouse membuat/mengubah jadwal untuk Return disetujui. */
    public function jadwalkanPenjemputan(Retur $retur, string $jadwal, ?string $catatan, User $petugas): Retur
    {
        $this->pastikanPeran($petugas, Peran::Admin, Peran::Warehouse);
        $catatan = $catatan === null ? null : trim($catatan);
        $catatan = $catatan === '' ? null : $catatan;

        if (! preg_match('/\d{1,2}:\d{2}/', $jadwal)) {
            throw ValidationException::withMessages(['jadwal_jemput' => 'Tanggal dan waktu penjemputan wajib diisi.']);
        }

        try {
            $waktu = CarbonImmutable::parse($jadwal);
        } catch (Throwable) {
            throw ValidationException::withMessages(['jadwal_jemput' => 'Tanggal dan waktu penjemputan tidak valid.']);
        }

        return DB::transaction(function () use ($retur, $waktu, $catatan, $petugas): Retur {
            $terkini = Retur::query()->lockForUpdate()->findOrFail($retur->id);
            $this->pastikanStatus($terkini, [StatusRetur::Disetujui, StatusRetur::Dijadwalkan]);
            $statusAsal = $terkini->status;
            $terkini->update([
                'jadwal_jemput' => $waktu,
                'catatan_jemput' => $catatan,
                'status' => StatusRetur::Dijadwalkan,
            ]);

            AuditLog::catat(
                $terkini,
                'retur_dijadwalkan',
                $statusAsal->value,
                StatusRetur::Dijadwalkan->value,
                null,
                ['jadwal_jemput' => $waktu->toIso8601String()],
                $petugas->id,
            );

            return $terkini->load(self::MUAT);
        });
    }

    /**
     * Simpan satu atau beberapa foto penjemputan, lalu tandai Return dijemput.
     * Foto ditulis dahulu; jika transaksi DB gagal, file yang baru ditulis dibersihkan.
     *
     * @param  array<int, UploadedFile>  $foto
     */
    public function unggahBuktiPenjemputan(Retur $retur, array $foto, User $petugas): Retur
    {
        $this->pastikanPeran($petugas, Peran::Admin, Peran::Warehouse);
        $this->validasiFoto($foto, 'foto_penjemputan', true);
        $pathsBaru = [];

        try {
            return DB::transaction(function () use ($retur, $foto, $petugas, &$pathsBaru): Retur {
                $terkini = Retur::query()->lockForUpdate()->findOrFail($retur->id);
                $this->pastikanStatus($terkini, [StatusRetur::Dijadwalkan]);
                if (! $terkini->jadwal_jemput) {
                    throw ValidationException::withMessages(['jadwal_jemput' => 'Jadwal penjemputan harus tersedia sebelum bukti diunggah.']);
                }

                $this->simpanFoto($terkini, $foto, 'bukti_penjemputan', $petugas, $pathsBaru);
                if (! $terkini->fotoBukti()->where('jenis', 'bukti_penjemputan')->exists()) {
                    throw ValidationException::withMessages(['foto_penjemputan' => 'Bukti penjemputan wajib tersedia.']);
                }

                $terkini->update([
                    'status' => StatusRetur::Dijemput,
                    'dijemput_at' => now(),
                ]);

                AuditLog::catat($terkini, 'retur_dijemput', StatusRetur::Dijadwalkan->value, StatusRetur::Dijemput->value, null, [], $petugas->id);

                return $terkini->load(self::MUAT);
            });
        } catch (Throwable $exception) {
            $this->hapusBerkas($pathsBaru);

            throw $exception;
        }
    }

    /**
     * @param  array<string, mixed>  $data
     */
    private function validasiDataDraft(array $data, bool $wajibIdentitas): void
    {
        $galat = [];
        foreach (['pesanan_id', 'item_pesanan_id'] as $kolom) {
            if (($wajibIdentitas || array_key_exists($kolom, $data)) && (! isset($data[$kolom]) || filter_var($data[$kolom], FILTER_VALIDATE_INT) === false || (int) $data[$kolom] < 1)) {
                $galat[$kolom] = 'Data pesanan dan produk wajib dipilih.';
            }
        }

        if (($wajibIdentitas || array_key_exists('qty', $data)) && (! isset($data['qty']) || filter_var($data['qty'], FILTER_VALIDATE_INT) === false || (int) $data['qty'] < 1)) {
            $galat['qty'] = 'Kuantitas Return harus berupa bilangan bulat lebih dari 0.';
        }
        if (($wajibIdentitas || array_key_exists('alasan', $data)) && (! isset($data['alasan']) || ! is_string($data['alasan']) || trim($data['alasan']) === '')) {
            $galat['alasan'] = 'Alasan Return wajib diisi.';
        }
        if (array_key_exists('jenis_penyelesaian', $data) && $data['jenis_penyelesaian'] !== null && ! in_array($data['jenis_penyelesaian'], ['refund', 'replacement'], true)) {
            $galat['jenis_penyelesaian'] = 'Pilih refund atau replacement.';
        }

        if ($galat !== []) {
            throw ValidationException::withMessages($galat);
        }
    }

    /** @param array<int, UploadedFile> $foto */
    private function validasiFoto(array $foto, string $field, bool $wajib = false): void
    {
        if ($wajib && $foto === []) {
            throw ValidationException::withMessages([$field => 'Unggah minimal satu foto.']);
        }

        foreach ($foto as $file) {
            if (! $file instanceof UploadedFile || ! $file->isValid() || ! str_starts_with((string) $file->getMimeType(), 'image/')) {
                throw ValidationException::withMessages([$field => 'Setiap bukti harus berupa file gambar yang valid.']);
            }
        }
    }

    /** @param array<int, UploadedFile> $foto @param array<int, string> $paths */
    private function simpanFoto(Retur $retur, array $foto, string $jenis, User $pengunggah, array &$paths): void
    {
        $disk = (string) config('filesystems.default', 'local');

        foreach ($foto as $file) {
            $path = $file->store("retur/{$retur->id}/{$jenis}", $disk);
            if (! is_string($path) || $path === '') {
                throw new \RuntimeException('File bukti Return gagal disimpan.');
            }

            $paths[] = $path;
            $retur->fotoBukti()->create([
                'jenis' => $jenis,
                'path' => $path,
                'nama_asli' => $file->getClientOriginalName(),
                'mime' => $file->getMimeType(),
                'ukuran' => $file->getSize(),
                'diunggah_oleh' => $pengunggah->id,
            ]);
        }
    }

    /** @param array<int, string> $paths */
    private function hapusBerkas(array $paths): void
    {
        if ($paths === []) {
            return;
        }

        $berhasil = Storage::disk((string) config('filesystems.default', 'local'))->delete($paths);
        if (! $berhasil) {
            Log::warning('Sebagian file foto Return gagal dibersihkan.', ['jumlah_file' => count($paths)]);
        }
    }

    private function retailerMilik(User $user): Retailer
    {
        $retailer = Retailer::query()->where('user_id', $user->id)->first();
        if (! $retailer) {
            throw new ApiException('Akun Retail tidak memiliki profil toko.', 403, 'RETAIL_TIDAK_VALID');
        }

        return $retailer;
    }

    private function kunciPesananMilikRetail(int|string $pesananId, Retailer $retailer, bool $wajibDiterima = true): Pesanan
    {
        $pesanan = Pesanan::query()->lockForUpdate()->find($pesananId);
        if (! $pesanan || (int) $pesanan->retailer_id !== (int) $retailer->id) {
            throw new ApiException('Pesanan tidak ditemukan.', 404, 'PESANAN_TIDAK_DITEMUKAN');
        }
        if ($wajibDiterima && $pesanan->status !== StatusPesanan::Diterima) {
            throw ValidationException::withMessages(['pesanan_id' => 'Return hanya dapat dibuat dari pesanan yang sudah diterima.']);
        }

        return $pesanan;
    }

    private function itemPesananUntukOrder(int|string $itemPesananId, Pesanan $pesanan): ItemPesanan
    {
        $item = ItemPesanan::query()
            ->where('pesanan_id', $pesanan->id)
            ->find($itemPesananId);

        if (! $item) {
            throw ValidationException::withMessages(['item_pesanan_id' => 'Produk harus berasal dari pesanan yang dipilih.']);
        }

        return $item;
    }

    private function pastikanProdukBelumDiajukan(int $pesananId, int $produkId, ?int $kecualiReturId = null): void
    {
        $sudahAda = Retur::query()
            ->where('pesanan_id', $pesananId)
            ->where('status', '!=', StatusRetur::Ditolak->value)
            ->whereHas('item', fn ($query) => $query->where('produk_id', $produkId))
            ->when($kecualiReturId !== null, fn ($query) => $query->whereKeyNot($kecualiReturId))
            ->exists();

        if ($sudahAda) {
            throw ValidationException::withMessages([
                'produk_id' => 'Produk ini sudah memiliki pengajuan Return yang belum ditolak pada pesanan tersebut.',
            ]);
        }
    }

    private function pastikanPemilik(Retur $retur, Retailer $retailer): void
    {
        if ((int) $retur->retailer_id !== (int) $retailer->id) {
            throw new ApiException('Pengajuan Return tidak ditemukan.', 404, 'RETUR_TIDAK_DITEMUKAN');
        }
    }

    /** @param array<int, StatusRetur> $diizinkan */
    private function pastikanStatus(Retur $retur, array $diizinkan): void
    {
        if (! in_array($retur->status, $diizinkan, true)) {
            $status = $retur->status instanceof StatusRetur ? $retur->status->label() : (string) $retur->status;
            throw new ApiException("Return berstatus \"{$status}\", tindakan ini tidak dapat dilakukan.", 409, 'STATUS_RETUR_TIDAK_VALID');
        }
    }

    private function pastikanPeran(User $user, Peran ...$diizinkan): void
    {
        $roles = array_map(fn (Peran $peran) => $peran->value, $diizinkan);
        if (! $user->hasAnyRole($roles)) {
            throw new ApiException('Peran akun tidak diizinkan melakukan tindakan Return ini.', 403, 'PERAN_TIDAK_DIIZINKAN');
        }
    }
}
