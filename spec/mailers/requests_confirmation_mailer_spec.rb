RSpec.describe RequestsConfirmationMailer, type: :mailer do
  let(:organization) { create(:organization, :with_items, email: "email@testthis.com") }
  let(:partner_user) { create(:partner_user, name: "Jane Smith") }
  let(:request) { create(:request, organization:, partner_user:) }
  let(:mail) { RequestsConfirmationMailer.confirmation_email(request) }

  let(:request_w_varied_quantities) { create(:request, :with_varied_quantities, organization: organization) }
  let(:mail_w_varied_quantities) { RequestsConfirmationMailer.confirmation_email(request_w_varied_quantities) }

  describe "#confirmation_email" do
    it 'renders the headers' do
      expect(mail.subject).to eq("#{request.organization.name} - Requests Confirmation")
      expect(mail.cc).to eq([request.partner.email])
      expect(mail.from).to include("no-reply@humanessentials.app")
    end

    it 'renders the body' do
      organization.update!(email: "me@org.com")
      expect(mail.body.encoded).to match('This email confirms')
      expect(mail.body.encoded).to match('For more info, please e-mail me@org.com')
    end

    it 'CCs the organization if they opt in' do
      request.organization.update!(receive_email_on_requests: true)
      expect(mail.cc).to eq([request.partner.email, request.organization.email])
      request.organization.update!(receive_email_on_requests: false)
      expect(RequestsConfirmationMailer.confirmation_email(request).cc).to eq([request.partner.email])
    end

    context "when partner_user is present for the request" do
      it "displays the name of the user" do
        expect(mail.body.encoded).to match("has received a request submitted by Jane Smith for")
      end

      it "sends to the partner_user's email" do
        expect(mail.to).to eq([request.partner_user.email])
      end
    end

    context "when no partner_user is specified for the request" do
      before { request.update(partner_user: nil) }

      it "doesn't mention who submitted the request" do
        expect(mail.body.encoded).to match("has received a request for")
      end

      it "sends to the partner's email" do
        expect(mail.to).to eq([request.partner.email])
      end
    end
  end

  it 'pairs the right quantities with the right item names' do
    organization.update!(email: "me@org.com")
    expect(mail_w_varied_quantities.body.encoded).to match('This email confirms')
    request_w_varied_quantities.request_items.each { |ri|
      expected_string = "#{Item.find(ri["item_id"]).name} - #{ri["quantity"]}"
      expect(mail_w_varied_quantities.body.encoded).to include(expected_string)
    }
  end

  it "shows units" do
    Flipper.enable(:enable_packs)
    item1 = create(:item, organization:)
    item2 = create(:item, organization:)
    create(:item_unit, item: item1, name: "Pack")
    create(:item_unit, item: item2, name: "Pack")
    request_items = [
      {item_id: item1.id, quantity: 1, request_unit: "Pack"},
      {item_id: item2.id, quantity: 7, request_unit: "Pack"}
    ]
    request = create(:request, :pending, request_items:)
    email = RequestsConfirmationMailer.confirmation_email(request)
    expect(email.body.encoded).to match("1 Pack")
    expect(email.body.encoded).to match("7 Packs")
  end

  it "skips units when are not provided" do
    Flipper.enable(:enable_packs)
    item = create(:item, organization:)
    create(:item_unit, item: item, name: "Pack")
    request = create(:request, :pending, request_items: [{item_id: item.id, quantity: 7}])
    email = RequestsConfirmationMailer.confirmation_email(request)

    expect(email.body.encoded).not_to match("7 Packs")
  end
end
